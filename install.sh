#!/bin/bash

echo "شروع نصب ربات ساده..."

# نصب پیش‌نیازها
apt-get update
apt-get install -y python3 python3-pip

# دریافت توکن
read -p "توکن ربات را وارد کنید: " BOT_TOKEN

# نصب پکیج تلگرام
pip3 install python-telegram-bot==13.12

# ایجاد فایل ربات
cat > bot.py << EOL
from telegram.ext import Updater, CommandHandler

def start(update, context):
    update.message.reply_text('سلام! به ربات خوش آمدید.')

def main():
    updater = Updater('${BOT_TOKEN}', use_context=True)
    updater.dispatcher.add_handler(CommandHandler('start', start))
    print('ربات در حال اجرا است...')
    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
    main()
EOL

# اجرای ربات
echo "در حال اجرای ربات..."
python3 bot.py 