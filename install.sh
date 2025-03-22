#!/bin/bash

# تعریف رنگ‌ها
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

# تابع تست اتصال به تلگرام
test_telegram_connection() {
    local token=$1
    echo -e "${YELLOW}در حال تست اتصال به تلگرام...${NC}"
    if curl -s "https://api.telegram.org/bot${token}/getMe" | grep -q "\"ok\":true"; then
        echo -e "${GREEN}اتصال به تلگرام موفقیت‌آمیز بود${NC}"
        return 0
    else
        echo -e "${RED}خطا در اتصال به تلگرام. لطفا توکن و دسترسی به اینترنت را بررسی کنید${NC}"
        return 1
    fi
}

# تابع تست اجرای ربات
test_bot() {
    echo -e "${YELLOW}در حال تست اجرای ربات...${NC}"
    cd /opt/netbox
    source venv/bin/activate
    
    # تست محیط مجازی
    if ! python3 -c "import sys; sys.exit(0 if sys.prefix != sys.base_prefix else 1)"; then
        echo -e "${RED}خطا: محیط مجازی به درستی فعال نشده است${NC}"
        return 1
    fi
    
    # تست وابستگی‌ها
    if ! python3 -c "import telegram; import dotenv"; then
        echo -e "${RED}خطا: وابستگی‌های مورد نیاز نصب نشده‌اند${NC}"
        return 1
    fi
    
    # تست فایل .env
    if ! python3 -c "
import os
from dotenv import load_dotenv
load_dotenv()
token = os.getenv('BOT_TOKEN')
admin = os.getenv('ADMIN_ID')
if not token or not admin:
    raise ValueError('متغیرهای محیطی BOT_TOKEN یا ADMIN_ID یافت نشدند')
print(f'Token: {token[:5]}... Admin ID: {admin}')
"; then
        echo -e "${RED}خطا در خواندن متغیرهای محیطی${NC}"
        return 1
    fi
    
    echo -e "${GREEN}تست‌های اولیه موفقیت‌آمیز بودند${NC}"
    return 0
}

# تابع نصب
install() {
    echo -e "${GREEN}شروع نصب ربات ساده...${NC}"
    
    # نصب پیش‌نیازها
    apt-get update
    apt-get install -y python3 python3-pip
    
    # دریافت توکن
    read -p "توکن ربات را وارد کنید: " BOT_TOKEN
    
    # ایجاد دایرکتوری
    mkdir -p /opt/netbox
    cd /opt/netbox
    
    # نصب پکیج‌های مورد نیاز
    pip3 install python-telegram-bot==13.12
    
    # ایجاد فایل ربات
    cat > /opt/netbox/bot.py << EOL
import logging
from telegram import Update
from telegram.ext import Updater, CommandHandler, CallbackContext

# تنظیم لاگ
logging.basicConfig(
    format='%(asctime)s - %(levelname)s - %(message)s',
    level=logging.INFO
)

def start(update: Update, context: CallbackContext) -> None:
    """پیام خوش‌آمد به کاربر"""
    user = update.effective_user
    update.message.reply_text(f'سلام {user.first_name}! به ربات خوش آمدید.')

def main():
    # راه‌اندازی ربات
    updater = Updater('${BOT_TOKEN}')
    dispatcher = updater.dispatcher
    dispatcher.add_handler(CommandHandler("start", start))
    
    print("ربات در حال اجرا است...")
    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
    main()
EOL
    
    # اجرای ربات
    echo -e "${GREEN}در حال اجرای ربات...${NC}"
    python3 /opt/netbox/bot.py
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