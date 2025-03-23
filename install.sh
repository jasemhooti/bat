#!/bin/bash

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# تابع ارسال پیام به تلگرام
send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${ADMIN_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML" > /dev/null
}

# تابع نصب
install() {
    echo -e "${YELLOW}شروع نصب ربات NetBox...${NC}"
    
    # حذف فایل‌های قبلی
    rm -rf /opt/netbox
    rm -f /etc/nginx/sites-enabled/netbox
    rm -f /etc/systemd/system/netbox.service
    
    # ایجاد دایرکتوری‌ها
    mkdir -p /opt/netbox
    mkdir -p /opt/netbox/utils
    mkdir -p /opt/netbox/pay
    mkdir -p /opt/netbox/phpqrcode
    mkdir -p /opt/netbox/settings
    mkdir -p /opt/netbox/assets
    mkdir -p /opt/netbox/backups
    
    # کپی فایل‌ها
    cp bot.py /opt/netbox/
    cp requirements.txt /opt/netbox/
    cp config.php /opt/netbox/
    cp createDB.php /opt/netbox/
    
    # ایجاد محیط مجازی
    echo -e "${YELLOW}ایجاد محیط مجازی پایتون...${NC}"
    python3 -m venv /opt/netbox/venv
    source /opt/netbox/venv/bin/activate
    
    # نصب پکیج‌های پایتون
    echo -e "${YELLOW}نصب پکیج‌های پایتون...${NC}"
    pip install --upgrade pip
    pip install -r requirements.txt
    
    # نصب پکیج‌های PHP
    echo -e "${YELLOW}نصب پکیج‌های PHP...${NC}"
    apt-get install -y php-pgsql php-curl php-gd php-mbstring php-xml php-zip
    
    # ساخت دیتابیس
    echo -e "${YELLOW}ساخت دیتابیس...${NC}"
    cd /opt/netbox
    php createDB.php
    
    # تنظیم Nginx
    rm -f /etc/nginx/sites-enabled/netbox
    rm -f /etc/nginx/sites-enabled/default
    
    cat > /etc/nginx/sites-available/netbox << EOL
server {
    listen 80;
    server_name ${DOMAIN};
    
    root /opt/netbox;
    index index.php index.html;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location /webhook.php {
        proxy_pass http://localhost:${WEBHOOK_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    root /opt/netbox;
    index index.php index.html;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location /webhook.php {
        proxy_pass http://localhost:${WEBHOOK_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOL
    
    ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/
    
    # تنظیم مجوزها
    chown -R www-data:www-data /opt/netbox
    chmod -R 755 /opt/netbox
    chmod -R 777 /opt/netbox/assets
    chmod -R 777 /opt/netbox/backups
    
    # راه‌اندازی مجدد سرویس‌ها
    systemctl restart nginx
    systemctl restart php-fpm
    
    # تنظیم سرویس
    cat > /etc/systemd/system/netbox.service << EOL
[Unit]
Description=NetBox Telegram Bot
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
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

# تابع آپدیت
update() {
    echo -e "${YELLOW}شروع آپدیت ربات NetBox...${NC}"
    
    # فعال‌سازی محیط مجازی
    source /opt/netbox/venv/bin/activate
    
    # آپدیت پکیج‌های پایتون
    echo -e "${YELLOW}آپدیت پکیج‌های پایتون...${NC}"
    pip install --upgrade -r requirements.txt
    
    # راه‌اندازی مجدد سرویس
    systemctl restart netbox
    
    # ارسال پیام به ادمین
    send_telegram_message "✅ آپدیت ربات با موفقیت انجام شد."
    
    echo -e "${GREEN}آپدیت ربات با موفقیت انجام شد.${NC}"
}

# تابع حذف
uninstall() {
    echo -e "${YELLOW}شروع حذف ربات NetBox...${NC}"
    
    # توقف و حذف سرویس
    systemctl stop netbox
    systemctl disable netbox
    rm -f /etc/systemd/system/netbox.service
    
    # حذف تنظیمات Nginx
    rm -f /etc/nginx/sites-enabled/netbox
    rm -f /etc/nginx/sites-available/netbox
    
    # حذف فایل‌ها
    rm -rf /opt/netbox
    
    # راه‌اندازی مجدد Nginx
    systemctl restart nginx
    
    # ارسال پیام به ادمین
    send_telegram_message "✅ حذف ربات با موفقیت انجام شد."
    
    echo -e "${GREEN}حذف ربات با موفقیت انجام شد.${NC}"
}

# تابع تنظیم وب‌هوک
setup_webhook() {
    echo -e "${YELLOW}شروع تنظیم وب‌هوک...${NC}"
    
    # دریافت اطلاعات
    read -p "لطفا توکن ربات را وارد کنید: " BOT_TOKEN
    read -p "لطفا شناسه ادمین را وارد کنید: " ADMIN_ID
    read -p "لطفا نام کاربری دیتابیس را وارد کنید: " DB_USER
    read -p "لطفا رمز عبور دیتابیس را وارد کنید: " DB_PASS
    read -p "لطفا دامنه یا IP سرور را وارد کنید: " DOMAIN
    read -p "لطفا پورت وب‌هوک را وارد کنید (پیش‌فرض: 8443): " WEBHOOK_PORT
    WEBHOOK_PORT=${WEBHOOK_PORT:-8443}
    
    # تنظیم متغیرهای محیطی
    cat > /opt/netbox/.env << EOL
BOT_TOKEN=${BOT_TOKEN}
ADMIN_ID=${ADMIN_ID}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
WEBHOOK_URL=https://${DOMAIN}
WEBHOOK_PORT=${WEBHOOK_PORT}
EOL
    
    # راه‌اندازی مجدد سرویس
    systemctl restart netbox
    
    # ارسال پیام به ادمین
    send_telegram_message "✅ تنظیم وب‌هوک با موفقیت انجام شد.\n\n🔗 آدرس وب‌هوک:\n🔸 HTTP: http://${DOMAIN}/webhook.php\n🔸 HTTPS: https://${DOMAIN}/webhook.php"
    
    echo -e "${GREEN}تنظیم وب‌هوک با موفقیت انجام شد.${NC}"
    echo -e "${YELLOW}آدرس وب‌هوک:${NC}"
    echo -e "${YELLOW}HTTP: http://${DOMAIN}/webhook.php${NC}"
    echo -e "${YELLOW}HTTPS: https://${DOMAIN}/webhook.php${NC}"
}

# منوی اصلی
while true; do
    echo -e "\n${YELLOW}منوی مدیریت ربات NetBox:${NC}"
    echo "1) نصب ربات"
    echo "2) آپدیت ربات"
    echo "3) حذف ربات"
    echo "4) تنظیم وب‌هوک"
    echo "5) خروج"
    
    read -p "لطفا یک گزینه را انتخاب کنید: " choice
    
    case $choice in
        1) install ;;
        2) update ;;
        3) uninstall ;;
        4) setup_webhook ;;
        5) exit 0 ;;
        *) echo -e "${RED}گزینه نامعتبر است.${NC}" ;;
    esac
done 