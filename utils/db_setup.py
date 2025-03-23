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
        # اتصال به PostgreSQL
        conn = await asyncpg.connect(
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASS'),
            host='localhost',
            database='postgres'
        )
        
        # ایجاد دیتابیس
        exists = await conn.fetchval(
            "SELECT 1 FROM pg_database WHERE datname = 'netbox_db'"
        )
        
        if not exists:
            await conn.execute('CREATE DATABASE netbox_db')
            logger.info("دیتابیس netbox_db با موفقیت ایجاد شد")
        
        # بستن اتصال به دیتابیس postgres
        await conn.close()
        
        # اتصال به دیتابیس جدید
        conn = await asyncpg.connect(
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASS'),
            host='localhost',
            database='netbox_db'
        )
        
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