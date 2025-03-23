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
    apt-get install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx postgresql postgresql-contrib

    # دریافت اطلاعات
    read -p "توکن ربات را وارد کنید: " BOT_TOKEN
    read -p "شناسه ادمین را وارد کنید: " ADMIN_ID
    read -p "نام کاربری دیتابیس را وارد کنید: " DB_USER
    read -p "رمز عبور دیتابیس را وارد کنید: " DB_PASS
    read -p "دامنه سرور را وارد کنید (مثال: bot.example.com): " DOMAIN
    read -p "پورت وب‌هوک را وارد کنید (پیش‌فرض: 8443): " WEBHOOK_PORT
    WEBHOOK_PORT=${WEBHOOK_PORT:-8443}

    # حذف گواهینامه SSL قبلی
    if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
        echo -e "${YELLOW}حذف گواهینامه SSL قبلی...${NC}"
        certbot delete --cert-name ${DOMAIN} --non-interactive
    fi

    # دریافت گواهینامه SSL جدید
    echo -e "${YELLOW}در حال دریافت گواهینامه SSL...${NC}"
    certbot certonly --nginx -d ${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN}

    # تنظیم وب‌هوک
    WEBHOOK_URL="https://${DOMAIN}/webhook"

    # ایجاد کاربر دیتابیس
    sudo -u postgres psql -c "DROP USER IF EXISTS ${DB_USER};"
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
    sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH SUPERUSER;"

    # نصب پکیج‌های پایتون
    echo -e "${YELLOW}نصب پکیج‌های پایتون...${NC}"
    pip3 install python-telegram-bot python-dotenv asyncpg apscheduler

    # ایجاد دایرکتوری
    mkdir -p /opt/netbox

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
    cat > /etc/nginx/sites-available/netbox << EOL
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    location /webhook {
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
    rm /etc/nginx/sites-enabled/default

    # راه‌اندازی مجدد Nginx
    systemctl restart nginx

    # ساخت دیتابیس
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
ExecStart=/usr/bin/python3 bot.py
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
    send_telegram_message "✅ نصب ربات با موفقیت انجام شد.\n\n🔗 آدرس وب‌هوک: ${WEBHOOK_URL}\n\n📝 اطلاعات دیتابیس:\n🔸 نام کاربری: ${DB_USER}\n🔸 رمز عبور: ${DB_PASS}\n🔸 نام دیتابیس: netbox_db"

    echo -e "${GREEN}نصب ربات با موفقیت انجام شد.${NC}"
    echo -e "${YELLOW}آدرس وب‌هوک: ${WEBHOOK_URL}${NC}"
}

# تابع بروزرسانی
update() {
    echo -e "${YELLOW}شروع بروزرسانی ربات...${NC}"
    
    # دریافت توکن و شناسه ادمین
    source /opt/netbox/.env
    
    # توقف سرویس
    systemctl stop netbox
    
    # بروزرسانی کد
    cd /opt/netbox
    git pull
    
    # بروزرسانی پکیج‌ها
    pip3 install -r requirements.txt
    
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
    
    # ارسال پیام به ادمین
    send_telegram_message "❌ ربات با موفقیت حذف شد."
    
    echo -e "${GREEN}حذف ربات با موفقیت انجام شد.${NC}"
}

# تابع تنظیم وب‌هوک
setup_webhook() {
    echo -e "${YELLOW}تنظیم وب‌هوک...${NC}"
    
    # دریافت اطلاعات
    read -p "دامنه سرور را وارد کنید (مثال: bot.example.com): " DOMAIN
    
    # بررسی وجود گواهینامه SSL
    if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
        echo -e "${YELLOW}در حال دریافت گواهینامه SSL...${NC}"
        certbot certonly --nginx -d ${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN}
    else
        echo -e "${GREEN}گواهینامه SSL قبلاً برای دامنه ${DOMAIN} صادر شده است.${NC}"
    fi
    
    # تنظیم Nginx
    cat > /etc/nginx/sites-available/netbox << EOL
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    location /webhook {
        proxy_pass http://localhost:8443;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOL
    
    # فعال‌سازی سایت
    ln -sf /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # تست و بارگذاری مجدد Nginx
    nginx -t && systemctl reload nginx
    
    # بروزرسانی تنظیمات وب‌هوک
    sed -i "s/WEBHOOK_MODE=polling/WEBHOOK_MODE=webhook/" /opt/netbox/.env
    sed -i "s/WEBHOOK_URL=.*/WEBHOOK_URL=https:\/\/${DOMAIN}\/webhook/" /opt/netbox/.env
    
    # راه‌اندازی مجدد سرویس
    systemctl restart netbox
    
    # ارسال پیام به ادمین
    source /opt/netbox/.env
    send_telegram_message "✅ تنظیم وب‌هوک با موفقیت انجام شد.\n\n🔗 آدرس وب‌هوک: https://${DOMAIN}/webhook"
    
    echo -e "${GREEN}تنظیم وب‌هوک با موفقیت انجام شد.${NC}"
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