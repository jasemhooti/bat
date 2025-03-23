import os
import logging
import asyncpg
from datetime import datetime
from dotenv import load_dotenv

# تنظیم لاگر
logger = logging.getLogger(__name__)

# لود کردن متغیرهای محیطی
load_dotenv()

class Database:
    _instance = None
    _pool = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(Database, cls).__new__(cls)
        return cls._instance
    
    async def connect(self):
        """اتصال به دیتابیس"""
        if self._pool is None:
            try:
                self._pool = await asyncpg.create_pool(
                    os.getenv('DATABASE_URL'),
                    min_size=1,
                    max_size=10
                )
                logger.info("اتصال به دیتابیس برقرار شد")
            except Exception as e:
                logger.error(f"خطا در اتصال به دیتابیس: {e}")
                raise
        return self._pool
    
    async def close(self):
        """بستن اتصال به دیتابیس"""
        if self._pool:
            await self._pool.close()
            self._pool = None
            logger.info("اتصال به دیتابیس بسته شد")
    
    async def execute(self, query: str, *args):
        """اجرای کوئری"""
        pool = await self.connect()
        try:
            async with pool.acquire() as conn:
                return await conn.execute(query, *args)
        except Exception as e:
            logger.error(f"خطا در اجرای کوئری: {e}")
            raise
    
    async def fetch(self, query: str, *args):
        """دریافت نتایج کوئری"""
        pool = await self.connect()
        try:
            async with pool.acquire() as conn:
                return await conn.fetch(query, *args)
        except Exception as e:
            logger.error(f"خطا در دریافت نتایج: {e}")
            raise
    
    async def fetchrow(self, query: str, *args):
        """دریافت یک ردیف از نتایج"""
        pool = await self.connect()
        try:
            async with pool.acquire() as conn:
                return await conn.fetchrow(query, *args)
        except Exception as e:
            logger.error(f"خطا در دریافت ردیف: {e}")
            raise
    
    async def get_stats(self):
        """دریافت آمار ربات"""
        try:
            total_users = await self.fetchrow("SELECT COUNT(*) FROM users")
            active_users = await self.fetchrow(
                "SELECT COUNT(*) FROM users WHERE last_activity > NOW() - INTERVAL '24 hours'"
            )
            total_messages = await self.fetchrow("SELECT COUNT(*) FROM messages")
            last_update = await self.fetchrow("SELECT MAX(created_at) FROM messages")
            
            return {
                'total_users': total_users[0] if total_users else 0,
                'active_users': active_users[0] if active_users else 0,
                'total_messages': total_messages[0] if total_messages else 0,
                'last_update': last_update[0].strftime('%Y-%m-%d %H:%M:%S') if last_update[0] else 'ندارد'
            }
        except Exception as e:
            logger.error(f"خطا در دریافت آمار: {e}")
            return {
                'total_users': 0,
                'active_users': 0,
                'total_messages': 0,
                'last_update': 'خطا در دریافت'
            }
    
    async def add_user(self, user_id: int, username: str, first_name: str):
        """افزودن کاربر جدید"""
        try:
            await self.execute("""
                INSERT INTO users (user_id, username, first_name, created_at)
                VALUES ($1, $2, $3, NOW())
                ON CONFLICT (user_id) DO UPDATE
                SET username = $2, first_name = $3, last_activity = NOW()
            """, user_id, username, first_name)
            logger.info(f"کاربر {user_id} با موفقیت اضافه شد")
        except Exception as e:
            logger.error(f"خطا در افزودن کاربر: {e}")
            raise
    
    async def add_message(self, user_id: int, message_text: str):
        """افزودن پیام جدید"""
        try:
            await self.execute("""
                INSERT INTO messages (user_id, message_text, created_at)
                VALUES ($1, $2, NOW())
            """, user_id, message_text)
            logger.info(f"پیام از کاربر {user_id} با موفقیت ثبت شد")
        except Exception as e:
            logger.error(f"خطا در ثبت پیام: {e}")
            raise 