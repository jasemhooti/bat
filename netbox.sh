#!/bin/bash

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# تابع نمایش منو
show_menu() {
    clear
    echo -e "${YELLOW}مدیریت ربات NetBox${NC}"
    echo "1) راه‌اندازی مجدد ربات"
    echo "2) توقف ربات"
    echo "3) شروع ربات"
    echo "4) وضعیت ربات"
    echo "5) مشاهده لاگ‌ها"
    echo "6) مشاهده اطلاعات دیتابیس"
    echo "7) بروزرسانی ربات"
    echo "8) پشتیبان‌گیری"
    echo "9) خروج"
}

# تابع راه‌اندازی مجدد
restart() {
    echo -e "${YELLOW}در حال راه‌اندازی مجدد ربات...${NC}"
    systemctl restart netbox
    echo -e "${GREEN}ربات با موفقیت راه‌اندازی مجدد شد${NC}"
}

# تابع توقف
stop() {
    echo -e "${RED}در حال متوقف کردن ربات...${NC}"
    systemctl stop netbox
    echo -e "${GREEN}ربات با موفقیت متوقف شد${NC}"
}

# تابع شروع
start() {
    echo -e "${GREEN}در حال شروع ربات...${NC}"
    systemctl start netbox
    echo -e "${GREEN}ربات با موفقیت شروع شد${NC}"
}

# تابع وضعیت
status() {
    systemctl status netbox
}

# تابع نمایش لاگ‌ها
show_logs() {
    journalctl -u netbox -n 100 --no-pager
}

# تابع نمایش اطلاعات دیتابیس
show_db_info() {
    if [ -f /opt/netbox/.env ]; then
        echo -e "${GREEN}اطلاعات دیتابیس:${NC}"
        grep DATABASE_URL /opt/netbox/.env
    else
        echo -e "${RED}فایل .env یافت نشد${NC}"
    fi
}

# تابع بروزرسانی
update() {
    echo -e "${YELLOW}در حال بروزرسانی ربات...${NC}"
    cd /opt/netbox
    git pull
    pip3 install -r requirements.txt
    systemctl restart netbox
    echo -e "${GREEN}بروزرسانی با موفقیت انجام شد${NC}"
}

# تابع پشتیبان‌گیری
backup() {
    echo -e "${YELLOW}در حال پشتیبان‌گیری...${NC}"
    BACKUP_DIR="/opt/netbox/backups"
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    
    # ایجاد دایرکتوری پشتیبان
    mkdir -p $BACKUP_DIR
    
    # پشتیبان‌گیری از دیتابیس
    if [ -f /opt/netbox/.env ]; then
        source /opt/netbox/.env
        DB_NAME=$(echo $DATABASE_URL | cut -d'/' -f4)
        pg_dump $DB_NAME > $BACKUP_DIR/db_backup_$BACKUP_DATE.sql
    fi
    
    # پشتیبان‌گیری از فایل‌های ربات
    tar -czf $BACKUP_DIR/files_backup_$BACKUP_DATE.tar.gz /opt/netbox
    
    echo -e "${GREEN}پشتیبان‌گیری با موفقیت انجام شد${NC}"
    echo "مسیر فایل‌های پشتیبان: $BACKUP_DIR"
}

# منوی اصلی
while true; do
    show_menu
    read -p "لطفا یک گزینه را انتخاب کنید: " choice
    case $choice in
        1) restart ;;
        2) stop ;;
        3) start ;;
        4) status ;;
        5) show_logs ;;
        6) show_db_info ;;
        7) update ;;
        8) backup ;;
        9) exit 0 ;;
        *) echo -e "${RED}گزینه نامعتبر${NC}" ;;
    esac
    read -p "برای ادامه Enter را فشار دهید..."
done 