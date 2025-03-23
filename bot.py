import os
import logging
import asyncpg
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
from dotenv import load_dotenv

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
    async with asyncpg.create_pool(**DB_CONFIG) as pool:
        await pool.execute('''
            INSERT INTO users (user_id, username, first_name)
            VALUES ($1, $2, $3)
            ON CONFLICT (user_id) DO UPDATE
            SET username = $2, first_name = $3
        ''', user.id, user.username, user.first_name)
    
    await update.message.reply_text(
        f"سلام {user.first_name}! به ربات NetBox خوش آمدید.\n"
        "برای مشاهده منو از دستور /menu استفاده کنید."
    )

async def echo(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """پاسخ به پیام‌های عادی"""
    user = update.effective_user
    message_text = update.message.text
    
    async with asyncpg.create_pool(**DB_CONFIG) as pool:
        # ذخیره پیام در دیتابیس
        await pool.execute('''
            INSERT INTO messages (user_id, message_text)
            VALUES ($1, $2)
        ''', user.id, message_text)
        
        # آپدیت آخرین فعالیت کاربر
        await pool.execute('''
            UPDATE users
            SET last_activity = NOW()
            WHERE user_id = $1
        ''', user.id)
    
    await update.message.reply_text("پیام شما دریافت شد!")

async def error(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """مدیریت خطاها"""
    logger.error(f"خطا در پردازش پیام: {context.error}")
    if update and update.effective_message:
        await update.effective_message.reply_text(
            "متاسفانه در پردازش پیام شما خطایی رخ داد. لطفا دوباره تلاش کنید."
        )

def main():
    """تابع اصلی"""
    # دریافت توکن از متغیرهای محیطی
    token = os.getenv('BOT_TOKEN')
    
    # ایجاد برنامه
    application = Application.builder().token(token).build()
    
    # اضافه کردن هندلرها
    application.add_handler(CommandHandler("start", start))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, echo))
    
    # اضافه کردن هندلر خطا
    application.add_error_handler(error)
    
    # تنظیم وب‌هوک
    webhook_url = os.getenv('WEBHOOK_URL')
    webhook_port = int(os.getenv('WEBHOOK_PORT', '8443'))
    
    # شروع ربات
    application.run_webhook(
        listen='0.0.0.0',
        port=webhook_port,
        url_path='/webhook.php',
        webhook_url=webhook_url
    )

if __name__ == '__main__':
    main() 