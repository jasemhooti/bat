import os
import asyncio
from dotenv import load_dotenv
from telegram.ext import Updater, CommandHandler, CallbackQueryHandler
from handlers.admin_handler import AdminHandler
from handlers.user_handler import UserHandler
from handlers.payment_handler import PaymentHandler
from handlers.game_handler import GameHandler
from database import Database
from config import Config
from utils.db_setup import init_db

# بارگذاری متغیرهای محیطی
load_dotenv()

async def setup():
    # راه‌اندازی دیتابیس
    try:
        await init_db()
    except Exception as e:
        print(f"Error initializing database: {e}")
        return False
    return True

def main():
    # تنظیمات اولیه
    if not asyncio.get_event_loop().run_until_complete(setup()):
        print("Failed to setup database. Exiting...")
        return

    db = Database()
    config = Config()
    
    try:
        # ایجاد نمونه از آپدیتر
        updater = Updater(token=os.getenv('BOT_TOKEN'))
        dispatcher = updater.dispatcher
        
        # ایجاد نمونه از هندلرها
        admin_handler = AdminHandler(db, config)
        user_handler = UserHandler(db, config)
        payment_handler = PaymentHandler(db, config)
        game_handler = GameHandler(db, config)
        
        # اضافه کردن هندلرها
        dispatcher.add_handler(CommandHandler('start', user_handler.start))
        dispatcher.add_handler(CommandHandler('admin', admin_handler.admin_panel))
        dispatcher.add_handler(CallbackQueryHandler(admin_handler.handle_callback, pattern='^admin_.*'))
        dispatcher.add_handler(CallbackQueryHandler(user_handler.handle_callback, pattern='^user_.*'))
        dispatcher.add_handler(CallbackQueryHandler(payment_handler.handle_callback, pattern='^payment_.*'))
        dispatcher.add_handler(CallbackQueryHandler(game_handler.handle_callback, pattern='^game_.*'))
        
        # شروع ربات
        print("Bot is starting...")
        updater.start_polling()
        print("Bot started successfully!")
        updater.idle()
    except Exception as e:
        print(f"Error starting bot: {e}")
    finally:
        # بستن اتصال دیتابیس
        if db._pool:
            asyncio.get_event_loop().run_until_complete(db.close())

if __name__ == '__main__':
    main() 