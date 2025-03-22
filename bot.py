import os
import logging
from datetime import datetime, timedelta
from dotenv import load_dotenv
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes
from database import Database
from config import Config
from handlers import (
    admin_handler,
    user_handler,
    payment_handler,
    game_handler,
    ticket_handler,
    panel_handler
)

# لود کردن متغیرهای محیطی
load_dotenv()

# تنظیمات لاگینگ
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

class NetBoxBot:
    def __init__(self):
        self.token = os.getenv('BOT_TOKEN')
        self.admin_id = int(os.getenv('ADMIN_ID'))
        self.db = Database()
        self.config = Config()
        
        # ایجاد نمونه از هندلرها
        self.admin_handler = admin_handler.AdminHandler(self.db, self.config)
        self.user_handler = user_handler.UserHandler(self.db, self.config)
        self.payment_handler = payment_handler.PaymentHandler(self.db, self.config)
        self.game_handler = game_handler.GameHandler(self.db, self.config)
        self.ticket_handler = ticket_handler.TicketHandler(self.db, self.config)
        self.panel_handler = panel_handler.PanelHandler(self.db, self.config)

    async def start(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """هندلر دستور /start"""
        user_id = update.effective_user.id
        
        # بررسی عضویت در کانال اجباری
        if not await self.check_channel_subscription(user_id, context):
            return
            
        # ثبت کاربر در دیتابیس
        self.db.add_user(user_id, update.effective_user.username)
        
        # نمایش منوی اصلی
        keyboard = [
            [InlineKeyboardButton("🛒 خرید کانفیگ", callback_data='buy_config')],
            [InlineKeyboardButton("👤 حساب کاربری", callback_data='account'),
             InlineKeyboardButton("🎮 بازی", callback_data='game')],
            [InlineKeyboardButton("💬 پشتیبانی", callback_data='support'),
             InlineKeyboardButton("📊 راهنما", callback_data='help')]
        ]
        
        if user_id == self.admin_id:
            keyboard.append([InlineKeyboardButton("⚙️ پنل مدیریت", callback_data='admin_panel')])
            
        reply_markup = InlineKeyboardMarkup(keyboard)
        await update.message.reply_text(
            "🌟 به ربات NetBox خوش آمدید!\n"
            "از منوی زیر گزینه مورد نظر خود را انتخاب کنید:",
            reply_markup=reply_markup
        )

    async def check_channel_subscription(self, user_id: int, context: ContextTypes.DEFAULT_TYPE) -> bool:
        """بررسی عضویت کاربر در کانال"""
        channel = self.config.get_required_channel()
        if not channel:
            return True
            
        try:
            member = await context.bot.get_chat_member(chat_id=channel, user_id=user_id)
            if member.status in ['member', 'administrator', 'creator']:
                return True
        except:
            pass
            
        keyboard = [[InlineKeyboardButton("عضویت در کانال", url=f"https://t.me/{channel}")]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await context.bot.send_message(
            chat_id=user_id,
            text="⚠️ برای استفاده از ربات ابتدا باید در کانال ما عضو شوید:",
            reply_markup=reply_markup
        )
        return False

    async def callback_handler(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """هندلر دکمه‌های شیشه‌ای"""
        query = update.callback_query
        data = query.data
        user_id = update.effective_user.id

        # بررسی عضویت در کانال
        if not await self.check_channel_subscription(user_id, context):
            await query.answer()
            return

        try:
            if data == 'buy_config':
                await self.user_handler.show_configs(update, context)
            elif data == 'account':
                await self.user_handler.show_account(update, context)
            elif data == 'game':
                await self.game_handler.show_game_menu(update, context)
            elif data == 'support':
                await self.ticket_handler.show_support(update, context)
            elif data == 'help':
                await self.show_help(update, context)
            elif data == 'admin_panel' and user_id == self.admin_id:
                await self.admin_handler.show_admin_panel(update, context)
            else:
                # ارسال به هندلرهای مربوطه
                if data.startswith('admin_'):
                    await self.admin_handler.handle_callback(update, context)
                elif data.startswith('config_'):
                    await self.user_handler.handle_callback(update, context)
                elif data.startswith('payment_'):
                    await self.payment_handler.handle_callback(update, context)
                elif data.startswith('game_'):
                    await self.game_handler.handle_callback(update, context)
                elif data.startswith('ticket_'):
                    await self.ticket_handler.handle_callback(update, context)
                elif data.startswith('panel_'):
                    await self.panel_handler.handle_callback(update, context)
        except Exception as e:
            logger.error(f"Error in callback handler: {e}")
            await query.answer("خطایی رخ داد. لطفا دوباره تلاش کنید.")

    async def show_help(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش راهنمای ربات"""
        help_text = """
🔰 راهنمای استفاده از ربات:

1️⃣ خرید کانفیگ:
- از منوی اصلی گزینه "خرید کانفیگ" را انتخاب کنید
- حجم مورد نظر خود را انتخاب کنید
- مبلغ را به شماره کارت نمایش داده شده واریز کنید
- رسید پرداخت را ارسال کنید
- پس از تایید، کانفیگ برای شما ارسال می‌شود

2️⃣ حساب کاربری:
- مشاهده اطلاعات حساب
- لیست کانفیگ‌های فعال
- موجودی حساب
- تاریخچه خریدها

3️⃣ بازی:
- بازی تک نفره
- بازی دو نفره آنلاین
- جوایز نقدی

4️⃣ پشتیبانی:
- ارسال تیکت به پشتیبانی
- پیگیری تیکت‌ها

❓ در صورت نیاز به راهنمایی بیشتر با پشتیبانی در ارتباط باشید.
        """
        keyboard = [[InlineKeyboardButton("🔙 بازگشت", callback_data='start')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await update.callback_query.edit_message_text(
            text=help_text,
            reply_markup=reply_markup
        )

    def run(self):
        """راه‌اندازی ربات"""
        # ایجاد اپلیکیشن
        application = Application.builder().token(self.token).build()

        # اضافه کردن هندلرها
        application.add_handler(CommandHandler('start', self.start))
        application.add_handler(CallbackQueryHandler(self.callback_handler))
        
        # شروع پولینگ
        application.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == '__main__':
    bot = NetBoxBot()
    bot.run() 