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

# تابع نصب
install() {
    echo -e "${YELLOW}شروع نصب ربات...${NC}"
    
    # نصب پیش‌نیازها
    apt-get update
    apt-get install -y python3 python3-pip python3-venv postgresql postgresql-contrib nginx certbot python3-certbot-nginx
    
    # دریافت اطلاعات
    read -p "توکن ربات را وارد کنید: " BOT_TOKEN
    read -p "شناسه ادمین را وارد کنید: " ADMIN_ID
    read -p "دامنه سرور را وارد کنید (مثال: bot.example.com): " DOMAIN
    read -p "نام کاربری دیتابیس را وارد کنید: " DB_USER
    read -p "رمز عبور دیتابیس را وارد کنید: " DB_PASS
    
    # دریافت گواهینامه SSL
    echo -e "${YELLOW}در حال دریافت گواهینامه SSL...${NC}"
    certbot certonly --nginx -d ${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN}
    
    # ایجاد دایرکتوری‌ها
    mkdir -p /opt/netbox
    mkdir -p /opt/netbox/logs
    mkdir -p /opt/netbox/utils
    
    # تنظیم مجوزها
    chown -R netbox:netbox /opt/netbox
    chmod -R 755 /opt/netbox
    
    # ایجاد محیط مجازی
    python3 -m venv /opt/netbox/venv
    source /opt/netbox/venv/bin/activate
    
    # نصب پکیج‌ها
    pip install --upgrade pip
    pip install python-telegram-bot python-dotenv asyncpg
    
    # ایجاد فایل .env
    cat > /opt/netbox/.env << EOL
BOT_TOKEN=${BOT_TOKEN}
ADMIN_ID=${ADMIN_ID}
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost/netbox_db
WEBHOOK_MODE=webhook
WEBHOOK_URL=https://${DOMAIN}
WEBHOOK_PORT=8443
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
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    location / {
        proxy_pass http://127.0.0.1:8443;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL
    
    # فعال‌سازی سایت
    ln -sf /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # تست و بارگذاری مجدد Nginx
    nginx -t && systemctl reload nginx
    
    # کپی فایل‌ها
    cp bot.py /opt/netbox/
    cp database.py /opt/netbox/
    cp -r utils /opt/netbox/
    
    # تنظیم سرویس
    cat > /etc/systemd/system/netbox.service << EOL
[Unit]
Description=NetBox Telegram Bot
After=network.target

[Service]
Type=simple
User=netbox
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
    curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${ADMIN_ID}" \
        -d "text=✅ نصب ربات با موفقیت انجام شد.\n\n🔗 آدرس وب‌هوک: https://${DOMAIN}" \
        -d "parse_mode=HTML" > /dev/null
    
    echo -e "${GREEN}نصب ربات با موفقیت انجام شد.${NC}"
    echo -e "${YELLOW}نکته: برای استفاده از وب‌هوک، مطمئن شوید که پورت 443 روی سرور شما باز است.${NC}"
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
    source venv/bin/activate
    pip install -r requirements.txt
    
    # شروع مجدد سرویس
    systemctl start netbox
    
    # ارسال پیام به ادمین
    curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${ADMIN_ID}" \
        -d "text=✅ بروزرسانی ربات با موفقیت انجام شد." \
        -d "parse_mode=HTML" > /dev/null
    
    echo -e "${GREEN}بروزرسانی ربات با موفقیت انجام شد.${NC}"
}

# تابع حذف
uninstall() {
    echo -e "${YELLOW}شروع حذف ربات...${NC}"
    
    # توقف و حذف سرویس
    systemctl stop netbox
    systemctl disable netbox
    rm -f /etc/systemd/system/netbox.service
    systemctl daemon-reload
    
    # حذف فایل‌ها
    rm -rf /opt/netbox
    
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
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    location / {
        proxy_pass http://127.0.0.1:8443;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
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
    sed -i "s/WEBHOOK_URL=.*/WEBHOOK_URL=https:\/\/${DOMAIN}/" /opt/netbox/.env
    
    # راه‌اندازی مجدد سرویس
    systemctl restart netbox
    
    # ارسال پیام به ادمین
    source /opt/netbox/.env
    curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${ADMIN_ID}" \
        -d "text=✅ تنظیم وب‌هوک با موفقیت انجام شد.\n\n🔗 آدرس وب‌هوک: https://${DOMAIN}" \
        -d "parse_mode=HTML" > /dev/null
    
    echo -e "${GREEN}تنظیم وب‌هوک با موفقیت انجام شد.${NC}"
    echo -e "${YELLOW}نکته: برای استفاده از وب‌هوک، مطمئن شوید که پورت 443 روی سرور شما باز است.${NC}"
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