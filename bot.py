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
        text = "📦 لیست کانفیگ‌های موجود:\n\n" \
               "1. پلن یک ماهه - 50,000 تومان\n" \
               "2. پلن سه ماهه - 140,000 تومان\n" \
               "3. پلن شش ماهه - 250,000 تومان\n\n" \
               "لطفاً پلن مورد نظر خود را انتخاب کنید:"
    elif query.data == 'account':
        text = "👤 حساب کاربری شما:\n\n" \
               "🆔 شناسه: {}\n" \
               "💰 موجودی: 0 تومان\n" \
               "📅 تاریخ عضویت: امروز".format(update.effective_user.id)
    elif query.data == 'game':
        text = "🎮 بخش بازی‌ها:\n\n" \
               "متأسفانه در حال حاضر این بخش در دسترس نیست."
    elif query.data == 'support':
        text = "💬 پشتیبانی:\n\n" \
               "برای ارتباط با پشتیبانی پیام خود را ارسال کنید."
    elif query.data == 'help':
        text = "📚 راهنمای استفاده از ربات:\n\n" \
               "1. برای خرید کانفیگ از دکمه 'خرید کانفیگ' استفاده کنید\n" \
               "2. برای مشاهده حساب خود از دکمه 'حساب کاربری' استفاده کنید\n" \
               "3. برای ارتباط با پشتیبانی از دکمه 'پشتیبانی' استفاده کنید"
    elif query.data == 'admin_panel' and str(update.effective_user.id) == os.getenv('ADMIN_ID'):
        text = "⚙️ پنل مدیریت:\n\n" \
               "- تعداد کاربران: 0\n" \
               "- تعداد فروش امروز: 0\n" \
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