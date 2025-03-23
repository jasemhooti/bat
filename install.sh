#!/bin/bash

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}نصب ربات تلگرام${NC}"
echo "----------------------------------------"

# نصب پیش‌نیازها
echo -e "${YELLOW}نصب پیش‌نیازها...${NC}"
apt-get update
apt-get install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx postgresql postgresql-contrib

# دریافت اطلاعات
read -p "توکن ربات را وارد کنید: " BOT_TOKEN
read -p "شناسه ادمین را وارد کنید: " ADMIN_ID
read -p "نام کاربری دیتابیس را وارد کنید: " DB_USER
read -p "رمز عبور دیتابیس را وارد کنید: " DB_PASS
read -p "دامنه یا IP سرور را وارد کنید: " SERVER_ADDRESS
read -p "پورت وب‌هوک را وارد کنید (پیش‌فرض: 8443): " WEBHOOK_PORT
WEBHOOK_PORT=${WEBHOOK_PORT:-8443}

# تنظیم پروتکل (http یا https)
if [[ $SERVER_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    PROTOCOL="http"
else
    PROTOCOL="https"
fi

# تنظیم وب‌هوک
WEBHOOK_URL="${PROTOCOL}://${SERVER_ADDRESS}:${WEBHOOK_PORT}/webhook"

# ایجاد کاربر دیتابیس
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
WEBHOOK_MODE=webhook
WEBHOOK_URL=${WEBHOOK_URL}
WEBHOOK_PORT=${WEBHOOK_PORT}
EOL

# تنظیم Nginx
cat > /etc/nginx/sites-available/netbox << EOL
server {
    listen 80;
    server_name ${SERVER_ADDRESS};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name ${SERVER_ADDRESS};

    ssl_certificate /etc/letsencrypt/live/${SERVER_ADDRESS}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${SERVER_ADDRESS}/privkey.pem;

    location /webhook {
        proxy_pass http://localhost:${WEBHOOK_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOL

ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# دریافت گواهینامه SSL
if [ ! -f "/etc/letsencrypt/live/${SERVER_ADDRESS}/fullchain.pem" ]; then
    certbot certonly --nginx -d ${SERVER_ADDRESS} --non-interactive --agree-tos --email admin@${SERVER_ADDRESS}
fi

# راه‌اندازی مجدد Nginx
systemctl restart nginx

# ساخت دیتابیس
python3 -c "
import asyncio
from utils.db_setup import setup_database
asyncio.run(setup_database())
"

echo -e "${GREEN}نصب با موفقیت انجام شد!${NC}"
echo -e "${YELLOW}آدرس وب‌هوک: ${WEBHOOK_URL}${NC}"
echo -e "${YELLOW}لطفاً مطمئن شوید که پورت ${WEBHOOK_PORT} در فایروال باز است.${NC}" 