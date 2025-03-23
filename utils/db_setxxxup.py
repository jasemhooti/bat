import asyncio
import asyncpg
import os
from dotenv import load_dotenv

load_dotenv()

async def init_db():
    # اتصال به دیتابیس
    conn = await asyncpg.connect(os.getenv('DATABASE_URL'))
    
    # ایجاد جداول
    await conn.execute('''
        CREATE TABLE IF NOT EXISTS users (
            user_id BIGINT PRIMARY KEY,
            username TEXT,
            balance INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    await conn.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
            id SERIAL PRIMARY KEY,
            user_id BIGINT REFERENCES users(user_id),
            amount INTEGER,
            type TEXT,
            status TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    await conn.execute('''
        CREATE TABLE IF NOT EXISTS games (
            id SERIAL PRIMARY KEY,
            user_id BIGINT REFERENCES users(user_id),
            game_type TEXT,
            bet_amount INTEGER,
            game_data JSONB,
            result TEXT,
            status TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    await conn.close()
    print("Database tables created successfully!")

if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(init_db()) 
