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

# تابع نصب
install() {
    echo -e "${GREEN}در حال نصب پیش‌نیازها...${NC}"
    apt update
    apt install -y python3 python3-pip postgresql postgresql-contrib nginx

    # دریافت اطلاعات از کاربر
    read -p "لطفا توکن ربات را وارد کنید: " BOT_TOKEN
    read -p "لطفا شناسه عددی ادمین را وارد کنید: " ADMIN_ID
    read -p "لطفا دامنه خود را وارد کنید (مثال: example.com): " DOMAIN
    read -p "لطفا نام کاربری دیتابیس را وارد کنید: " DB_USER
    read -p "لطفا رمز عبور دیتابیس را وارد کنید: " DB_PASS

    # ایجاد دیتابیس
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
    sudo -u postgres psql -c "CREATE DATABASE netbox_db OWNER $DB_USER;"

    # کلون کردن مخزن
    git clone https://github.com/YOUR_REPO/netbox.git /opt/netbox
    cd /opt/netbox

    # نصب وابستگی‌ها
    pip3 install -r requirements.txt

    # ایجاد فایل .env
    cat > .env << EOL
BOT_TOKEN=$BOT_TOKEN
ADMIN_ID=$ADMIN_ID
DATABASE_URL=postgresql://$DB_USER:$DB_PASS@localhost/netbox_db
DOMAIN=$DOMAIN
EOL

    # ایجاد سرویس systemd
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

[Install]
WantedBy=multi-user.target
EOL

    # راه‌اندازی سرویس
    systemctl daemon-reload
    systemctl enable netbox
    systemctl start netbox

    # تنظیم Nginx
    cat > /etc/nginx/sites-available/netbox << EOL
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOL

    ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx

    echo -e "${GREEN}نصب با موفقیت انجام شد!${NC}"
    echo -e "اطلاعات دیتابیس:"
    echo -e "URL: postgresql://$DB_USER:$DB_PASS@localhost/netbox_db"
    echo -e "نام کاربری: $DB_USER"
    echo -e "رمز عبور: $DB_PASS"
    echo -e "دامنه پنل: http://$DOMAIN"
}

# تابع بروزرسانی
update() {
    echo -e "${YELLOW}در حال بروزرسانی...${NC}"
    cd /opt/netbox
    git pull
    pip3 install -r requirements.txt
    systemctl restart netbox
    echo -e "${GREEN}بروزرسانی با موفقیت انجام شد${NC}"
}

# تابع حذف
uninstall() {
    echo -e "${RED}در حال حذف...${NC}"
    systemctl stop netbox
    systemctl disable netbox
    rm -f /etc/systemd/system/netbox.service
    rm -rf /opt/netbox
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