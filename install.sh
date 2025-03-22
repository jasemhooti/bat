#!/bin/bash

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# تابع نمایش منو
show_menu() {
    clear
    echo -e "${YELLOW}به نصب کننده NetBox خوش آمدید${NC}"
    echo "1) نصب ربات"
    echo "2) بروزرسانی ربات"
    echo "3) حذف ربات"
    echo "4) خروج"
}

# تابع ایجاد فایل‌های پروژه
create_project_files() {
    # ایجاد requirements.txt
    cat > requirements.txt << EOL
python-telegram-bot==13.12
psycopg2==2.8.6
python-dotenv==0.19.2
aiohttp==3.8.1
asyncpg==0.25.0
EOL

    # ایجاد bot.py
    cat > bot.py << EOL
import os
from dotenv import load_dotenv
from telegram.ext import Updater, CommandHandler, CallbackQueryHandler
from handlers.admin_handler import AdminHandler
from handlers.user_handler import UserHandler
from handlers.payment_handler import PaymentHandler
from handlers.game_handler import GameHandler
from database import Database
from config import Config

# بارگذاری متغیرهای محیطی
load_dotenv()

def main():
    # تنظیمات اولیه
    db = Database()
    config = Config()
    
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
    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
    main()
EOL

    # ایجاد ساختار پوشه‌ها
    mkdir -p handlers
    mkdir -p utils

    # ایجاد فایل‌های هندلر
    touch handlers/__init__.py
    touch utils/__init__.py

    # ایجاد database.py
    cat > database.py << EOL
import os
from datetime import datetime
import asyncpg

class Database:
    def __init__(self):
        self.conn = None
        self.DATABASE_URL = os.getenv('DATABASE_URL')

    async def connect(self):
        if not self.conn:
            self.conn = await asyncpg.connect(self.DATABASE_URL)
            await self.create_tables()

    async def create_tables(self):
        await self.conn.execute('''
            CREATE TABLE IF NOT EXISTS users (
                user_id BIGINT PRIMARY KEY,
                username TEXT,
                balance INTEGER DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        await self.conn.execute('''
            CREATE TABLE IF NOT EXISTS transactions (
                id SERIAL PRIMARY KEY,
                user_id BIGINT REFERENCES users(user_id),
                amount INTEGER,
                type TEXT,
                status TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        await self.conn.execute('''
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
EOL

    # ایجاد config.py
    cat > config.py << EOL
import os

class Config:
    def __init__(self):
        self.ADMIN_ID = int(os.getenv('ADMIN_ID'))
        self.DOMAIN = os.getenv('DOMAIN')

    def get_game_settings(self):
        return {
            'min_bet': 10000,  # 10,000 تومان
            'max_bet': 1000000,  # 1,000,000 تومان
            'single_player_enabled': True
        }
EOL
}

# تابع نصب
install() {
    # بررسی دسترسی روت
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}لطفا اسکریپت را با دسترسی روت اجرا کنید (sudo)${NC}"
        exit 1
    fi

    echo -e "${GREEN}در حال نصب پیش‌نیازها...${NC}"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3 \
        python3-pip \
        python3-dev \
        python3-venv \
        postgresql \
        postgresql-contrib \
        postgresql-server-dev-all \
        libpq-dev \
        gcc \
        nginx \
        php-fpm \
        php-pgsql \
        build-essential

    # ایجاد کاربر netbox
    if ! id "netbox" &>/dev/null; then
        useradd -r -s /bin/bash -d /opt/netbox -m netbox
    fi

    # دریافت اطلاعات از کاربر
    read -p "لطفا توکن ربات را وارد کنید: " BOT_TOKEN
    read -p "لطفا شناسه عددی ادمین را وارد کنید: " ADMIN_ID
    read -p "لطفا دامنه خود را وارد کنید (مثال: example.com): " DOMAIN
    read -p "لطفا نام کاربری دیتابیس را وارد کنید: " DB_USER
    read -p "لطفا رمز عبور دیتابیس را وارد کنید: " DB_PASS

    # ایجاد دایرکتوری نصب و فایل‌های پروژه
    mkdir -p /opt/netbox
    cd /opt/netbox

    # ایجاد محیط مجازی
    python3 -m venv venv
    source venv/bin/activate

    # آپگرید pip و نصب ابزارهای ضروری
    pip3 install --no-cache-dir --upgrade pip setuptools wheel

    create_project_files

    # دانلود و نصب Adminer
    mkdir -p /opt/netbox/public
    curl -o /opt/netbox/public/adminer.php https://www.adminer.org/latest.php

    # تنظیم مالکیت فایل‌ها
    chown -R netbox:netbox /opt/netbox
    chown www-data:www-data /opt/netbox/public/adminer.php

    # ایجاد دیتابیس
    echo -e "${GREEN}در حال تنظیم دیتابیس...${NC}"
    
    # تنظیم دسترسی‌های PostgreSQL
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
    echo "host    all             all             127.0.0.1/32            md5" > /etc/postgresql/*/main/pg_hba.conf
    echo "host    all             all             ::1/128                 md5" >> /etc/postgresql/*/main/pg_hba.conf
    
    # راه‌اندازی مجدد PostgreSQL
    systemctl restart postgresql
    
    # ایجاد کاربر و دیتابیس
    su - postgres -c "psql -v ON_ERROR_STOP=1 -q -c \"DO \\\$\\\$ BEGIN IF EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN RAISE NOTICE 'Role exists, skipping'; ELSE CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' CREATEDB; END IF; END \\\$\\\$;\""
    su - postgres -c "psql -v ON_ERROR_STOP=1 -q -c \"DROP DATABASE IF EXISTS netbox_db;\""
    su - postgres -c "psql -v ON_ERROR_STOP=1 -q -c \"CREATE DATABASE netbox_db;\""
    su - postgres -c "psql -v ON_ERROR_STOP=1 -q -c \"GRANT ALL PRIVILEGES ON DATABASE netbox_db TO $DB_USER;\""
    
    # تنظیم مجوزهای دیتابیس
    su - postgres -c "psql -v ON_ERROR_STOP=1 -q -d netbox_db -c \"GRANT ALL ON SCHEMA public TO $DB_USER;\""

    # ایجاد فایل .env
    cat > /opt/netbox/.env << EOL
BOT_TOKEN=$BOT_TOKEN
ADMIN_ID=$ADMIN_ID
DATABASE_URL=postgresql://$DB_USER:$DB_PASS@127.0.0.1:5432/netbox_db
DOMAIN=$DOMAIN
EOL

    # تنظیم دسترسی‌های فایل .env
    chown netbox:netbox /opt/netbox/.env
    chmod 600 /opt/netbox/.env

    # نصب وابستگی‌ها
    echo -e "${GREEN}در حال نصب وابستگی‌ها...${NC}"
    su - netbox -c "cd /opt/netbox && \
        source venv/bin/activate && \
        pip3 install --no-cache-dir --upgrade pip setuptools wheel && \
        export LDFLAGS='-L/usr/local/lib' && \
        pip3 install --no-cache-dir -r requirements.txt"

    # ایجاد سرویس systemd
    cat > /etc/systemd/system/netbox.service << EOL
[Unit]
Description=NetBox Telegram Bot
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=netbox
Group=netbox
WorkingDirectory=/opt/netbox
Environment=PATH=/opt/netbox/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/opt/netbox/venv/bin/python3 bot.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

    # تنظیم Nginx
    cat > /etc/nginx/sites-available/netbox << EOL
server {
    listen 80;
    server_name $DOMAIN;

    # پنل مدیریت دیتابیس
    location /adminer {
        alias /opt/netbox/public;
        index adminer.php;
        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
            fastcgi_pass unix:/var/run/php/php-fpm.sock;
        }
    }

    # ربات
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

    # فعال‌سازی سایت در Nginx
    ln -sf /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # راه‌اندازی مجدد سرویس‌ها
    systemctl restart postgresql
    systemctl restart php*-fpm
    systemctl restart nginx

    # راه‌اندازی سرویس ربات
    systemctl daemon-reload
    systemctl enable netbox
    systemctl start netbox

    echo -e "${GREEN}نصب با موفقیت انجام شد!${NC}"
    echo -e "اطلاعات دیتابیس:"
    echo -e "نام کاربری: $DB_USER"
    echo -e "رمز عبور: $DB_PASS"
    echo -e "\nاطلاعات پنل مدیریت دیتابیس:"
    echo -e "آدرس: http://$DOMAIN/adminer"
    echo -e "نوع دیتابیس: PostgreSQL"
    echo -e "سرور: localhost"
    echo -e "نام کاربری: $DB_USER"
    echo -e "رمز عبور: $DB_PASS"
    echo -e "نام دیتابیس: netbox_db"
    echo -e "\nلطفا این اطلاعات را در جای امنی ذخیره کنید."

    # ذخیره اطلاعات در فایل
    cat > /opt/netbox/db_info.txt << EOL
اطلاعات دیتابیس:
نام کاربری: $DB_USER
رمز عبور: $DB_PASS
نام دیتابیس: netbox_db
آدرس: localhost
پورت: 5432

اطلاعات پنل مدیریت دیتابیس:
آدرس: http://$DOMAIN/adminer
نوع دیتابیس: PostgreSQL
سرور: localhost
نام کاربری: $DB_USER
رمز عبور: $DB_PASS
نام دیتابیس: netbox_db
EOL

    chmod 600 /opt/netbox/db_info.txt
    chown netbox:netbox /opt/netbox/db_info.txt
}

# تابع بروزرسانی
update() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}لطفا اسکریپت را با دسترسی روت اجرا کنید (sudo)${NC}"
        exit 1
    fi

    echo -e "${YELLOW}در حال بروزرسانی...${NC}"
    systemctl stop netbox
    
    cd /opt/netbox
    create_project_files
    chown -R netbox:netbox /opt/netbox
    
    su - netbox -c "cd /opt/netbox && pip3 install --user -r requirements.txt"
    
    systemctl start netbox
    echo -e "${GREEN}بروزرسانی با موفقیت انجام شد${NC}"
}

# تابع حذف
uninstall() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}لطفا اسکریپت را با دسترسی روت اجرا کنید (sudo)${NC}"
        exit 1
    fi

    echo -e "${RED}در حال حذف...${NC}"
    systemctl stop netbox
    systemctl disable netbox
    rm -f /etc/systemd/system/netbox.service
    rm -rf /opt/netbox
    rm -f /etc/nginx/sites-enabled/netbox
    rm -f /etc/nginx/sites-available/netbox
    systemctl restart nginx
    
    read -p "آیا می‌خواهید کاربر netbox نیز حذف شود؟ (y/n): " DEL_USER
    if [ "$DEL_USER" = "y" ]; then
        userdel -r netbox
    fi
    
    echo -e "${GREEN}حذف با موفقیت انجام شد${NC}"
}

# منوی اصلی
while true; do
    show_menu
    read -p "لطفا یک گزینه را انتخاب کنید: " choice
    case $choice in
        1) install ;;
        2) update ;;
        3) uninstall ;;
        4) exit 0 ;;
        *) echo -e "${RED}گزینه نامعتبر${NC}" ;;
    esac
    read -p "برای ادامه Enter را فشار دهید..."
done 