#!/bin/bash

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}تنظیم وب‌هوک ربات تلگرام${NC}"
echo "----------------------------------------"

# دریافت اطلاعات
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
WEBHOOK_URL="${PROTOCOL}://${SERVER_ADDRESS}:${WEBHOOK_PORT}"

# ویرایش فایل .env
sed -i "s/WEBHOOK_MODE=.*/WEBHOOK_MODE=webhook/" /opt/netbox/.env
sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=${WEBHOOK_URL}|" /opt/netbox/.env
sed -i "s/WEBHOOK_PORT=.*/WEBHOOK_PORT=${WEBHOOK_PORT}/" /opt/netbox/.env

# راه‌اندازی مجدد سرویس
systemctl restart netbox

echo -e "${GREEN}تنظیم وب‌هوک با موفقیت انجام شد.${NC}"
echo -e "${YELLOW}آدرس وب‌هوک: ${WEBHOOK_URL}${NC}"

# نمایش وضعیت سرویس
echo -e "\n${YELLOW}وضعیت سرویس:${NC}"
systemctl status netbox | cat 