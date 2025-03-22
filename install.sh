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
        python3-venv

    # ایجاد کاربر netbox
    if ! id "netbox" &>/dev/null; then
        useradd -r -s /bin/bash -d /opt/netbox -m netbox
    fi

    # دریافت اطلاعات از کاربر
    read -p "لطفا توکن ربات را وارد کنید: " BOT_TOKEN
    read -p "لطفا شناسه عددی ادمین را وارد کنید: " ADMIN_ID

    # ایجاد دایرکتوری نصب
    mkdir -p /opt/netbox
    cd /opt/netbox

    # ایجاد محیط مجازی
    python3 -m venv venv
    source venv/bin/activate

    # ایجاد فایل‌های پروژه
    cat > requirements.txt << EOL
python-telegram-bot==13.12
python-dotenv==0.19.2
EOL

    cat > bot.py << EOL
import os
from dotenv import load_dotenv
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Updater, CommandHandler, CallbackQueryHandler, CallbackContext

# بارگذاری متغیرهای محیطی
load_dotenv()

def start(update: Update, context: CallbackContext):
    """هندلر دستور /start"""
    keyboard = [
        [InlineKeyboardButton("🛒 خرید کانفیگ", callback_data='buy_config')],
        [InlineKeyboardButton("👤 حساب کاربری", callback_data='account'),
         InlineKeyboardButton("🎮 بازی", callback_data='game')],
        [InlineKeyboardButton("💬 پشتیبانی", callback_data='support'),
         InlineKeyboardButton("📊 راهنما", callback_data='help')]
    ]
    
    if str(update.effective_user.id) == os.getenv('ADMIN_ID'):
        keyboard.append([InlineKeyboardButton("⚙️ پنل مدیریت", callback_data='admin_panel')])
        
    reply_markup = InlineKeyboardMarkup(keyboard)
    update.message.reply_text(
        "🌟 به ربات NetBox خوش آمدید!\n"
        "از منوی زیر گزینه مورد نظر خود را انتخاب کنید:",
        reply_markup=reply_markup
    )

def button(update: Update, context: CallbackContext):
    """هندلر دکمه‌های شیشه‌ای"""
    query = update.callback_query
    query.answer()
    
    if query.data == 'buy_config':
        text = "📦 لیست کانفیگ‌های موجود:\\n\\n" \\
               "1. پلن یک ماهه - 50,000 تومان\\n" \\
               "2. پلن سه ماهه - 140,000 تومان\\n" \\
               "3. پلن شش ماهه - 250,000 تومان\\n\\n" \\
               "لطفاً پلن مورد نظر خود را انتخاب کنید:"
    elif query.data == 'account':
        text = "👤 حساب کاربری شما:\\n\\n" \\
               "🆔 شناسه: {}\\n" \\
               "💰 موجودی: 0 تومان\\n" \\
               "📅 تاریخ عضویت: امروز".format(update.effective_user.id)
    elif query.data == 'game':
        text = "🎮 بخش بازی‌ها:\\n\\n" \\
               "متأسفانه در حال حاضر این بخش در دسترس نیست."
    elif query.data == 'support':
        text = "💬 پشتیبانی:\\n\\n" \\
               "برای ارتباط با پشتیبانی پیام خود را ارسال کنید."
    elif query.data == 'help':
        text = "📚 راهنمای استفاده از ربات:\\n\\n" \\
               "1. برای خرید کانفیگ از دکمه 'خرید کانفیگ' استفاده کنید\\n" \\
               "2. برای مشاهده حساب خود از دکمه 'حساب کاربری' استفاده کنید\\n" \\
               "3. برای ارتباط با پشتیبانی از دکمه 'پشتیبانی' استفاده کنید"
    elif query.data == 'admin_panel' and str(update.effective_user.id) == os.getenv('ADMIN_ID'):
        text = "⚙️ پنل مدیریت:\\n\\n" \\
               "- تعداد کاربران: 0\\n" \\
               "- تعداد فروش امروز: 0\\n" \\
               "- درآمد امروز: 0 تومان"
    else:
        text = "⚠️ این بخش در حال حاضر در دسترس نیست."
    
    query.edit_message_text(text=text)

def main():
    # ایجاد نمونه از آپدیتر
    updater = Updater(token=os.getenv('BOT_TOKEN'))
    dispatcher = updater.dispatcher
    
    # اضافه کردن هندلرها
    dispatcher.add_handler(CommandHandler('start', start))
    dispatcher.add_handler(CallbackQueryHandler(button))
    
    # شروع ربات
    print("Bot is starting...")
    updater.start_polling()
    print("Bot started successfully!")
    updater.idle()

if __name__ == '__main__':
    main()
EOL

    # ایجاد فایل .env
    cat > .env << EOL
BOT_TOKEN=$BOT_TOKEN
ADMIN_ID=$ADMIN_ID
EOL

    # تنظیم مالکیت فایل‌ها
    chown -R netbox:netbox /opt/netbox
    chmod 600 /opt/netbox/.env

    # نصب وابستگی‌ها
    echo -e "${GREEN}در حال نصب وابستگی‌ها...${NC}"
    su - netbox -c "cd /opt/netbox && \
        source venv/bin/activate && \
        pip3 install --no-cache-dir -r requirements.txt"

    # ایجاد سرویس systemd
    cat > /etc/systemd/system/netbox.service << EOL
[Unit]
Description=NetBox Telegram Bot
After=network.target

[Service]
Type=simple
User=netbox
Group=netbox
WorkingDirectory=/opt/netbox
Environment=PATH=/opt/netbox/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/opt/netbox/venv/bin/python3 /opt/netbox/bot.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

    # تنظیم مجوزهای سرویس
    chmod 644 /etc/systemd/system/netbox.service

    # راه‌اندازی سرویس
    systemctl daemon-reload
    systemctl enable netbox
    systemctl restart netbox

    # نمایش وضعیت سرویس
    echo -e "\nوضعیت سرویس ربات:"
    systemctl status netbox --no-pager -l

    echo -e "\n${GREEN}نصب با موفقیت انجام شد!${NC}"
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