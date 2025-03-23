import os
import logging
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
from dotenv import load_dotenv
import asyncpg
import asyncio

# تنظیم لاگر
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# لود کردن متغیرهای محیطی
load_dotenv()

# تنظیمات دیتابیس
DB_CONFIG = {
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASS'),
    'host': 'localhost',
    'database': 'netbox_db'
}

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /start"""
    user = update.effective_user
    await update.message.reply_text(
        f'سلام {user.first_name}! 👋\n\n'
        'به ربات NetBox خوش آمدید.\n'
        'من آماده کمک به شما هستم.'
    )
    
    # ذخیره کاربر در دیتابیس
    async with asyncpg.create_pool(**DB_CONFIG) as pool:
        await pool.execute('''
            INSERT INTO users (user_id, username, first_name)
            VALUES ($1, $2, $3)
            ON CONFLICT (user_id) DO UPDATE
            SET username = $2, first_name = $3, last_activity = NOW()
        ''', user.id, user.username, user.first_name)

async def echo(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """پاسخ به پیام‌های معمولی"""
    user = update.effective_user
    text = update.message.text
    
    # ذخیره پیام در دیتابیس
    async with asyncpg.create_pool(**DB_CONFIG) as pool:
        await pool.execute('''
            INSERT INTO messages (user_id, message_text)
            VALUES ($1, $2)
        ''', user.id, text)
    
    await update.message.reply_text(f'پیام شما دریافت شد: {text}')

async def error(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """مدیریت خطاها"""
    logger.error(f"خطا در پردازش پیام: {context.error}")

def main():
    """تابع اصلی"""
    # دریافت تنظیمات از فایل .env
    bot_token = os.getenv('BOT_TOKEN')
    webhook_url = os.getenv('WEBHOOK_URL')
    webhook_port = int(os.getenv('WEBHOOK_PORT', 8443))
    
    # ایجاد برنامه
    application = Application.builder().token(bot_token).build()
    
    # اضافه کردن هندلرها
    application.add_handler(CommandHandler("start", start))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, echo))
    
    # اضافه کردن هندلر خطا
    application.add_error_handler(error)
    
    # تنظیم وب‌هوک
    application.run_webhook(
        listen='0.0.0.0',
        port=webhook_port,
        url_path='webhook.php',
        webhook_url=webhook_url
    )

if __name__ == '__main__':
    main() 