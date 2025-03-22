import os
from datetime import datetime
import asyncpg
from dotenv import load_dotenv

load_dotenv()

class Database:
    _instance = None
    _pool = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(Database, cls).__new__(cls)
        return cls._instance

    async def init(self):
        if self._pool is None:
            try:
                self._pool = await asyncpg.create_pool(
                    os.getenv('DATABASE_URL'),
                    min_size=1,
                    max_size=10
                )
                print("Database connection pool created successfully!")
            except Exception as e:
                print(f"Error creating database pool: {e}")
                raise

    async def close(self):
        if self._pool:
            await self._pool.close()
            self._pool = None

    async def execute(self, query: str, *args):
        if not self._pool:
            await self.init()
        async with self._pool.acquire() as conn:
            try:
                return await conn.execute(query, *args)
            except Exception as e:
                print(f"Database execute error: {e}")
                raise

    async def fetch(self, query: str, *args):
        if not self._pool:
            await self.init()
        async with self._pool.acquire() as conn:
            try:
                return await conn.fetch(query, *args)
            except Exception as e:
                print(f"Database fetch error: {e}")
                raise

    async def fetchrow(self, query: str, *args):
        if not self._pool:
            await self.init()
        async with self._pool.acquire() as conn:
            try:
                return await conn.fetchrow(query, *args)
            except Exception as e:
                print(f"Database fetchrow error: {e}")
                raise 