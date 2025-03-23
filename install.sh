#!/bin/bash

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# تابع نمایش منو
show_menu() {
    clear
    echo -e "${YELLOW}=== منوی مدیریت ربات ===${NC}"
    echo "1) نصب ربات"
    echo "2) بروزرسانی ربات"
    echo "3) حذف ربات"
    echo "4) تنظیم وب‌هوک"
    echo "5) خروج"
    echo
    read -p "لطفاً یک گزینه را انتخاب کنید: " choice
}

# تابع ارسال پیام به ربات
send_telegram_message() {
    local message="$1"
    if [ ! -z "$BOT_TOKEN" ] && [ ! -z "$ADMIN_ID" ]; then
        curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d "chat_id=${ADMIN_ID}" \
            -d "text=${message}" \
            -d "parse_mode=HTML" > /dev/null
    fi
}

# تابع نصب
install() {
    echo -e "${YELLOW}شروع نصب ربات...${NC}"
    
    # نصب پیش‌نیازها
    echo -e "${YELLOW}نصب پیش‌نیازها...${NC}"
    apt-get update
    apt-get install -y python3 python3-pip python3-venv python3-full nginx postgresql postgresql-contrib

    # دریافت اطلاعات
    read -p "توکن ربات را وارد کنید: " BOT_TOKEN
    read -p "شناسه ادمین را وارد کنید: " ADMIN_ID
    read -p "نام کاربری دیتابیس را وارد کنید: " DB_USER
    read -p "رمز عبور دیتابیس را وارد کنید: " DB_PASS
    read -p "دامنه سرور را وارد کنید (مثال: bot.example.com): " DOMAIN
    read -p "پورت وب‌هوک را وارد کنید (پیش‌فرض: 8443): " WEBHOOK_PORT
    WEBHOOK_PORT=${WEBHOOK_PORT:-8443}

    # تنظیم وب‌هوک
    WEBHOOK_URL="https://${DOMAIN}/webhook.php"

    # ایجاد کاربر دیتابیس
    sudo -u postgres psql -c "DROP USER IF EXISTS ${DB_USER};"
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
    sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH SUPERUSER;"

    # ایجاد دایرکتوری
    mkdir -p /opt/netbox
    mkdir -p /opt/netbox/utils

    # ایجاد فایل db_setup.py
    cat > /opt/netbox/utils/db_setup.py << EOL
import os
import logging
import asyncpg
from dotenv import load_dotenv

# تنظیم لاگر
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
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
EOL

    # ایجاد محیط مجازی
    echo -e "${YELLOW}ایجاد محیط مجازی پایتون...${NC}"
    python3 -m venv /opt/netbox/venv
    source /opt/netbox/venv/bin/activate

    # نصب پکیج‌های پایتون
    echo -e "${YELLOW}نصب پکیج‌های پایتون...${NC}"
    pip install --upgrade pip
    pip install -r requirements.txt

    # ایجاد فایل .env
    cat > /opt/netbox/.env << EOL
BOT_TOKEN=${BOT_TOKEN}
ADMIN_ID=${ADMIN_ID}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost/netbox_db
WEBHOOK_MODE=webhook
WEBHOOK_URL=${WEBHOOK_URL}
WEBHOOK_PORT=${WEBHOOK_PORT}
EOL

    # تنظیم Nginx
    rm -f /etc/nginx/sites-enabled/netbox
    rm -f /etc/nginx/sites-enabled/default

    cat > /etc/nginx/sites-available/netbox << EOL
server {
    listen 80;
    server_name ${DOMAIN};

    location /webhook.php {
        proxy_pass http://localhost:${WEBHOOK_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location / {
        proxy_pass http://localhost:${WEBHOOK_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    location /webhook.php {
        proxy_pass http://localhost:${WEBHOOK_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location / {
        proxy_pass http://localhost:${WEBHOOK_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOL

    ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/

    # راه‌اندازی مجدد Nginx
    systemctl restart nginx

    # ساخت دیتابیس
    cd /opt/netbox
    python3 -c "
import asyncio
from utils.db_setup import setup_database
asyncio.run(setup_database())
"

    # تنظیم سرویس
    cat > /etc/systemd/system/netbox.service << EOL
[Unit]
Description=NetBox Telegram Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/netbox
Environment=PATH=/opt/netbox/venv/bin
ExecStart=/opt/netbox/venv/bin/python3 bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

    # فعال‌سازی و شروع سرویس
    systemctl daemon-reload
    systemctl enable netbox
    systemctl start netbox

    # ارسال پیام به ادمین
    send_telegram_message "✅ نصب ربات با موفقیت انجام شد.\n\n🔗 آدرس وب‌هوک:\n🔸 HTTP: http://${DOMAIN}/webhook.php\n🔸 HTTPS: https://${DOMAIN}/webhook.php\n\n📝 اطلاعات دیتابیس:\n🔸 نام کاربری: ${DB_USER}\n🔸 رمز عبور: ${DB_PASS}\n🔸 نام دیتابیس: netbox_db"

    echo -e "${GREEN}نصب ربات با موفقیت انجام شد.${NC}"
    echo -e "${YELLOW}آدرس وب‌هوک:${NC}"
    echo -e "${YELLOW}HTTP: http://${DOMAIN}/webhook.php${NC}"
    echo -e "${YELLOW}HTTPS: https://${DOMAIN}/webhook.php${NC}"
}

# تابع بروزرسانی
update() {
    echo -e "${YELLOW}شروع بروزرسانی ربات...${NC}"
    
    # دریافت توکن و شناسه ادمین
    source /opt/netbox/.env
    
    # توقف سرویس
    systemctl stop netbox
    
    # فعال‌سازی محیط مجازی
    source /opt/netbox/venv/bin/activate
    
    # بروزرسانی پکیج‌ها
    pip install --upgrade pip
    pip install -r requirements.txt
    
    # شروع مجدد سرویس
    systemctl start netbox
    
    # ارسال پیام به ادمین
    send_telegram_message "✅ بروزرسانی ربات با موفقیت انجام شد."
    
    echo -e "${GREEN}بروزرسانی ربات با موفقیت انجام شد.${NC}"
}

# تابع حذف
uninstall() {
    echo -e "${YELLOW}شروع حذف ربات...${NC}"
    
    # دریافت توکن و شناسه ادمین
    source /opt/netbox/.env
    
    # توقف و حذف سرویس
    systemctl stop netbox
    systemctl disable netbox
    rm -f /etc/systemd/system/netbox.service
    systemctl daemon-reload
    
    # حذف فایل‌ها
    rm -rf /opt/netbox
    rm -f /etc/nginx/sites-enabled/netbox
    
    # ارسال پیام به ادمین
    send_telegram_message "❌ ربات با موفقیت حذف شد."
    
    echo -e "${GREEN}حذف ربات با موفقیت انجام شد.${NC}"
}

# تابع تنظیم وب‌هوک
setup_webhook() {
    echo -e "${YELLOW}تنظیم وب‌هوک...${NC}"
    
    # دریافت اطلاعات
    read -p "دامنه سرور را وارد کنید (مثال: bot.example.com): " DOMAIN
    
    # تنظیم Nginx
    rm -f /etc/nginx/sites-enabled/netbox
    rm -f /etc/nginx/sites-enabled/default

    cat > /etc/nginx/sites-available/netbox << EOL
server {
    listen 80;
    server_name ${DOMAIN};

    location /webhook.php {
        proxy_pass http://localhost:8443;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    location /webhook.php {
        proxy_pass http://localhost:8443;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOL
    
    # فعال‌سازی سایت
    ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/
    
    # تست و بارگذاری مجدد Nginx
    nginx -t && systemctl reload nginx
    
    # بروزرسانی تنظیمات وب‌هوک
    sed -i "s/WEBHOOK_MODE=polling/WEBHOOK_MODE=webhook/" /opt/netbox/.env
    sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=https://${DOMAIN}/webhook.php|" /opt/netbox/.env
    
    # راه‌اندازی مجدد سرویس
    systemctl restart netbox
    
    # ارسال پیام به ادمین
    source /opt/netbox/.env
    send_telegram_message "✅ تنظیم وب‌هوک با موفقیت انجام شد.\n\n🔗 آدرس وب‌هوک:\n🔸 HTTP: http://${DOMAIN}/webhook.php\n🔸 HTTPS: https://${DOMAIN}/webhook.php"
    
    echo -e "${GREEN}تنظیم وب‌هوک با موفقیت انجام شد.${NC}"
    echo -e "${YELLOW}آدرس وب‌هوک:${NC}"
    echo -e "${YELLOW}HTTP: http://${DOMAIN}/webhook.php${NC}"
    echo -e "${YELLOW}HTTPS: https://${DOMAIN}/webhook.php${NC}"
}

# حلقه اصلی
while true; do
    show_menu
    case $choice in
        1) install ;;
        2) update ;;
        3) uninstall ;;
        4) setup_webhook ;;
        5) exit 0 ;;
        *) echo -e "${RED}گزینه نامعتبر است.${NC}" ;;
    esac
    read -p "برای ادامه کلید Enter را فشار دهید..."
done 