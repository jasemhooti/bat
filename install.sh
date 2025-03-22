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
    curl -o /opt/netbox/public/index.php https://www.adminer.org/latest.php

    # تنظیم مالکیت فایل‌ها
    chown -R netbox:netbox /opt/netbox
    chown www-data:www-data /opt/netbox/public/index.php
    chmod 644 /opt/netbox/public/index.php

    # ایجاد دایرکتوری‌های لاگ و تنظیم دسترسی‌ها
    mkdir -p /var/log/netbox
    touch /var/log/netbox/bot.log /var/log/netbox/bot.error.log
    chown -R netbox:netbox /var/log/netbox
    chmod 755 /var/log/netbox
    chmod 644 /var/log/netbox/bot.log /var/log/netbox/bot.error.log

    # تنظیم PostgreSQL
    PG_VERSION=$(ls /etc/postgresql/)
    PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

    # تنظیم postgresql.conf
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF
    sed -i "s/#port = 5432/port = 5432/" $PG_CONF

    # تنظیم pg_hba.conf
    cat > $PG_HBA << EOL
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all            postgres                                peer
local   all            all                                     md5
host    all            all             127.0.0.1/32           md5
host    all            all             ::1/128                md5
host    all            all             0.0.0.0/0              md5
EOL

    # راه‌اندازی مجدد PostgreSQL با حالت صحیح
    if systemctl is-active postgresql >/dev/null; then
        systemctl stop postgresql
    fi
    pg_ctlcluster $PG_VERSION main start

    # صبر برای اطمینان از راه‌اندازی کامل PostgreSQL
    sleep 5

    # تست اتصال به PostgreSQL
    if ! su - postgres -c "psql -c '\l'" >/dev/null 2>&1; then
        echo -e "${RED}خطا در اتصال به PostgreSQL${NC}"
        exit 1
    fi

    # ایجاد کاربر و دیتابیس با خطایابی بیشتر
    su - postgres -c "psql -v ON_ERROR_STOP=1 -c \"CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' CREATEDB;\" || true"
    su - postgres -c "psql -v ON_ERROR_STOP=1 -c \"CREATE DATABASE netbox_db OWNER $DB_USER;\" || true"
    su - postgres -c "psql -v ON_ERROR_STOP=1 -d netbox_db -c \"GRANT ALL ON SCHEMA public TO $DB_USER;\""

    # تنظیم مجدد Nginx
    cat > /etc/nginx/sites-available/netbox << EOL
server {
    listen 80;
    server_name $DOMAIN;

    root /opt/netbox/public;
    index index.php;

    location /db {
        try_files \$uri \$uri/ /index.php?\$query_string;
        
        location ~ \.php$ {
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:/run/php/php-fpm.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param PATH_INFO \$fastcgi_path_info;
        }
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    access_log /var/log/nginx/netbox_access.log;
    error_log /var/log/nginx/netbox_error.log debug;
}
EOL

    # اطمینان از وجود دایرکتوری‌های لاگ Nginx
    mkdir -p /var/log/nginx
    touch /var/log/nginx/netbox_access.log /var/log/nginx/netbox_error.log
    chown -R www-data:adm /var/log/nginx
    chmod 755 /var/log/nginx
    chmod 644 /var/log/nginx/*.log

    # حذف لینک پیش‌فرض و ایجاد لینک جدید
    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/

    # تست تنظیمات Nginx
    nginx -t

    # راه‌اندازی مجدد سرویس‌ها با ترتیب صحیح
    systemctl daemon-reload
    systemctl restart postgresql || pg_ctlcluster $PG_VERSION main restart
    systemctl restart php*-fpm
    systemctl restart nginx
    
    # راه‌اندازی سرویس ربات
    systemctl enable netbox
    systemctl restart netbox

    # نمایش وضعیت سرویس‌ها با جزئیات بیشتر
    echo -e "\nوضعیت PostgreSQL:"
    pg_lsclusters
    
    echo -e "\nتست اتصال به دیتابیس:"
    su - postgres -c "psql -c '\l'"
    
    echo -e "\nوضعیت Nginx:"
    nginx -t
    curl -I http://localhost/db
    
    echo -e "\nوضعیت سرویس ربات:"
    systemctl status netbox --no-pager -l
    
    echo -e "\nلاگ‌های خطای ربات:"
    if [ -f "/var/log/netbox/bot.error.log" ]; then
        tail -n 20 /var/log/netbox/bot.error.log
    else
        echo "فایل لاگ هنوز ایجاد نشده است"
    fi
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