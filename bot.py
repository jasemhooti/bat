import os
import logging
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application,
    CommandHandler,
    CallbackQueryHandler,
    ContextTypes,
    MessageHandler,
    filters
)
from dotenv import load_dotenv
from database import Database
from utils.db_setup import setup_database
from utils.logger import setup_logger

# تنظیم لاگر
logger = setup_logger()

# لود کردن متغیرهای محیطی
load_dotenv()

# دریافت تنظیمات از متغیرهای محیطی
BOT_TOKEN = os.getenv('BOT_TOKEN')
ADMIN_ID = int(os.getenv('ADMIN_ID', 0))
WEBHOOK_URL = os.getenv('WEBHOOK_URL', '')
WEBHOOK_PORT = int(os.getenv('WEBHOOK_PORT', 8443))

# تنظیمات وب‌هوک
WEBHOOK_MODE = os.getenv('WEBHOOK_MODE', 'polling').lower() == 'webhook'

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
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
    
    await update.message.reply_text(
        f"سلام {user.first_name}! به ربات خوش آمدید.\n"
        "لطفاً یکی از گزینه‌های زیر را انتخاب کنید:",
        reply_markup=reply_markup
    )

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """پردازش دکمه‌های اینلاین"""
    query = update.callback_query
    await query.answer()
    
    if query.data == 'stats':
        await show_stats(query, context)
    elif query.data == 'settings':
        await show_settings(query, context)
    elif query.data == 'help':
        await show_help(query, context)
    elif query.data == 'support':
        await show_support(query, context)

async def show_stats(query, context):
    """نمایش آمار"""
    db = Database()
    stats = await db.get_stats()
    
    await query.edit_message_text(
        f"📊 آمار ربات:\n\n"
        f"👥 تعداد کاربران: {stats['total_users']}\n"
        f"✅ کاربران فعال: {stats['active_users']}\n"
        f"📝 تعداد پیام‌ها: {stats['total_messages']}\n"
        f"🔄 آخرین بروزرسانی: {stats['last_update']}"
    )

async def show_settings(query, context):
    """نمایش تنظیمات"""
    keyboard = [
        [InlineKeyboardButton("🔙 بازگشت", callback_data='back')]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        "⚙️ تنظیمات ربات:\n\n"
        "در حال حاضر تنظیمات در دسترس نیست.",
        reply_markup=reply_markup
    )

async def show_help(query, context):
    """نمایش راهنما"""
    keyboard = [
        [InlineKeyboardButton("🔙 بازگشت", callback_data='back')]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        "📝 راهنمای استفاده از ربات:\n\n"
        "1. برای شروع از دستور /start استفاده کنید\n"
        "2. از منوی اصلی گزینه مورد نظر را انتخاب کنید\n"
        "3. برای ارتباط با پشتیبانی از گزینه پشتیبانی استفاده کنید",
        reply_markup=reply_markup
    )

async def show_support(query, context):
    """نمایش اطلاعات پشتیبانی"""
    keyboard = [
        [InlineKeyboardButton("🔙 بازگشت", callback_data='back')]
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    
    await query.edit_message_text(
        "❓ پشتیبانی:\n\n"
        "برای ارتباط با پشتیبانی:\n"
        "📧 ایمیل: support@example.com\n"
        "💬 تلگرام: @support",
        reply_markup=reply_markup
    )

async def error_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """مدیریت خطاها"""
    logger.error(f"خطا در پردازش درخواست: {context.error}")
    if update and update.effective_message:
        await update.effective_message.reply_text(
            "متأسفانه خطایی رخ داد. لطفاً دوباره تلاش کنید."
        )

async def notify_admin(message: str) -> None:
    """ارسال پیام به ادمین"""
    if ADMIN_ID:
        try:
            application = Application.builder().token(BOT_TOKEN).build()
            await application.bot.send_message(chat_id=ADMIN_ID, text=message)
        except Exception as e:
            logger.error(f"خطا در ارسال پیام به ادمین: {e}")

def main() -> None:
    """تابع اصلی"""
    try:
        # تنظیم دیتابیس
        setup_database()
        
        # ایجاد اپلیکیشن
        application = Application.builder().token(BOT_TOKEN).build()
        
        # اضافه کردن هندلرها
        application.add_handler(CommandHandler("start", start))
        application.add_handler(CallbackQueryHandler(button_handler))
        application.add_error_handler(error_handler)
        
        # تنظیم وب‌هوک یا پولینگ
        if WEBHOOK_MODE:
            application.run_webhook(
                listen='0.0.0.0',
                port=WEBHOOK_PORT,
                url_path=BOT_TOKEN,
                webhook_url=WEBHOOK_URL
            )
        else:
            application.run_polling(allowed_updates=Update.ALL_TYPES)
            
    except Exception as e:
        logger.error(f"خطا در اجرای ربات: {e}")
        raise

if __name__ == '__main__':
    main() 