import os
import logging
import asyncpg
from dotenv import load_dotenv

# تنظیم لاگر
logger = logging.getLogger(__name__)

# لود کردن متغیرهای محیطی
load_dotenv()

async def setup_database():
    """تنظیم اولیه دیتابیس"""
    try:
        # اتصال به دیتابیس
        conn = await asyncpg.connect(os.getenv('DATABASE_URL'))
        
        # ایجاد جداول
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS users (
                user_id BIGINT PRIMARY KEY,
                username TEXT,
                first_name TEXT,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            )
        ''')
        
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS messages (
                id SERIAL PRIMARY KEY,
                user_id BIGINT REFERENCES users(user_id),
                message_text TEXT,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            )
        ''')
        
        await conn.execute('''
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT,
                updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            )
        ''')
        
        logger.info("جداول دیتابیس با موفقیت ایجاد شدند")
        
        # بستن اتصال
        await conn.close()
        
    except Exception as e:
        logger.error(f"خطا در تنظیم دیتابیس: {e}")
        raise

if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(setup_database()) 