from telegram.ext import Updater, CommandHandler

def start(update, context):
    update.message.reply_text('سلام! به ربات خوش آمدید.')

def main():
    # توکن ربات خود را اینجا قرار دهید
    updater = Updater('YOUR_BOT_TOKEN_HERE', use_context=True)
    
    # اضافه کردن هندلر دستور /start
    updater.dispatcher.add_handler(CommandHandler('start', start))
    
    # شروع ربات
    print('ربات در حال اجرا است...')
    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
    main() 