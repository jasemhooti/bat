import os
import logging
from telegram.ext import Updater, CommandHandler, MessageHandler, Filters
from dotenv import load_dotenv
from database import Database
from utils.db_setup import setup_database
from utils.logger import setup_logger

# تنظیم لاگر
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# لود کردن متغیرهای محیطی
load_dotenv()

# دریافت تنظیمات از متغیرهای محیطی
BOT_TOKEN = os.getenv('BOT_TOKEN')
ADMIN_ID = int(os.getenv('ADMIN_ID', 0))
WEBHOOK_URL = os.getenv('WEBHOOK_URL', '')
WEBHOOK_PORT = int(os.getenv('WEBHOOK_PORT', 8443))

# تنظیمات وب‌هوک
WEBHOOK_MODE = os.getenv('WEBHOOK_MODE', 'polling').lower() == 'webhook'

def start(update, context):
    """دستور /start"""
    user = update.effective_user
    logger.info(f"کاربر {user.id} ({user.username}) دستور /start را اجرا کرد")
    
    keyboard = [
        [
            InlineKeyboardButton("📊 آمار", callback_data='stats'),
            InlineKeyboardButton("⚙️ تنظیمات", callback_data='settings')
        ],
        [
            InlineKeyboardButton("📝 راهنما", callback_data='help'),
            InlineKeyboardButton("❓ پشتیبانی", callback_data='support')
        ]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    update.message.reply_text(
        f"سلام {user.first_name}! به ربات خوش آمدید.\n"
        "لطفاً یکی از گزینه‌های زیر را انتخاب کنید:",
        reply_markup=reply_markup
    )

def echo(update, context):
    """پاسخ به پیام‌های کاربر"""
    update.message.reply_text(update.message.text)

def error(update, context):
    """لاگ کردن خطاها"""
    logger.error(f'خطا: {context.error}')
    if update and update.effective_message:
        update.effective_message.reply_text(
            "متأسفانه خطایی رخ داد. لطفاً دوباره تلاش کنید."
        )

async def notify_admin(message: str) -> None:
    """ارسال پیام به ادمین"""
    if ADMIN_ID:
        try:
            updater = Updater(BOT_TOKEN, use_context=True)
            await updater.bot.send_message(chat_id=ADMIN_ID, text=message)
        except Exception as e:
            logger.error(f"خطا در ارسال پیام به ادمین: {e}")

def main():
    """تابع اصلی"""
    try:
        # تنظیم دیتابیس
        setup_database()
        
        # ایجاد آپدیتر
        updater = Updater(BOT_TOKEN, use_context=True)
        
        # دریافت دیسپچر
        dp = updater.dispatcher
        
        # اضافه کردن هندلرها
        dp.add_handler(CommandHandler("start", start))
        dp.add_handler(MessageHandler(Filters.text & ~Filters.command, echo))
        
        # اضافه کردن هندلر خطا
        dp.add_error_handler(error)
        
        # تنظیم وب‌هوک
        updater.start_webhook(
            listen='0.0.0.0',
            port=WEBHOOK_PORT,
            url_path='webhook'
        )
        updater.bot.set_webhook(url=WEBHOOK_URL)
        
        # شروع ربات
        logger.info(f'ربات در حال اجرا است...\nوب‌هوک: {WEBHOOK_URL}')
        updater.idle()
        
    except Exception as e:
        logger.error(f"خطا در اجرای ربات: {e}")
        raise

if __name__ == '__main__':
    main() 