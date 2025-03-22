from datetime import datetime
from typing import Optional, List, Dict, Any
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes
from database import Database
from config import Config

class UserHandler:
    def __init__(self, db: Database, config: Config):
        self.db = db
        self.config = config

    async def show_configs(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش لیست کانفیگ‌ها"""
        query = update.callback_query
        
        # دریافت پلن‌های فعال از پنل‌ها
        plans = [
            {"name": "پلن اقتصادی", "volume": 5, "duration": 30, "price": 50000},
            {"name": "پلن استاندارد", "volume": 10, "duration": 30, "price": 90000},
            {"name": "پلن ویژه", "volume": 20, "duration": 30, "price": 160000}
        ]
        
        configs_text = "🛒 لیست کانفیگ‌های موجود:\n\n"
        keyboard = []
        
        for i, plan in enumerate(plans):
            configs_text += (
                f"📍 {plan['name']}:\n"
                f"💾 حجم: {plan['volume']} گیگابایت\n"
                f"⏱ مدت: {plan['duration']} روز\n"
                f"💰 قیمت: {plan['price']:,} تومان\n\n"
            )
            keyboard.append([
                InlineKeyboardButton(f"خرید {plan['name']}", 
                                   callback_data=f'config_buy_{i}')
            ])
        
        keyboard.append([InlineKeyboardButton("🔙 بازگشت", callback_data='start')])
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(configs_text, reply_markup=reply_markup)

    async def show_account(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش اطلاعات حساب کاربری"""
        query = update.callback_query
        user_id = update.effective_user.id
        
        # دریافت اطلاعات کاربر
        user = self.db.get_user(user_id)
        if not user:
            await query.answer("❌ خطا در دریافت اطلاعات کاربر!")
            return
            
        # دریافت آمار کاربر
        stats = self.db.get_user_stats(user_id)
        
        account_text = (
            "👤 اطلاعات حساب کاربری:\n\n"
            f"🆔 شناسه: {user.user_id}\n"
            f"💰 موجودی: {user.balance:,} تومان\n"
            f"👥 تعداد زیرمجموعه: {len(user.referrals)}\n"
            f"🎮 تعداد بازی‌ها: {stats['total_games']}\n"
            f"✅ برد: {stats['wins']} | ⭕️ مساوی: {stats['draws']} | ❌ باخت: {stats['losses']}\n"
            f"📅 تاریخ عضویت: {user.join_date}\n\n"
            "📍 کانفیگ‌های فعال:"
        )
        
        # دریافت کانفیگ‌های فعال
        active_configs = self.db.get_user_configs(user_id)
        if active_configs:
            for config in active_configs:
                if config.is_active:
                    account_text += f"\n\n🔰 {config.name}:\n"
                    account_text += f"💾 حجم باقیمانده: {config.volume} گیگابایت\n"
                    account_text += f"⏱ زمان باقیمانده: {(config.expiry_date - datetime.utcnow()).days} روز"
        else:
            account_text += "\n\n❌ هیچ کانفیگ فعالی ندارید!"
        
        keyboard = [
            [InlineKeyboardButton("💳 افزایش موجودی", callback_data='account_deposit'),
             InlineKeyboardButton("💰 برداشت", callback_data='account_withdraw')],
            [InlineKeyboardButton("📊 گزارش مصرف", callback_data='account_usage'),
             InlineKeyboardButton("🔄 تمدید", callback_data='account_renew')],
            [InlineKeyboardButton("🔙 بازگشت", callback_data='start')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(account_text, reply_markup=reply_markup)

    async def handle_callback(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت کالبک‌های کاربر"""
        query = update.callback_query
        data = query.data
        user_id = update.effective_user.id
        
        try:
            if data.startswith('config_buy_'):
                await self.handle_config_purchase(update, context)
            
            elif data == 'account_deposit':
                await self.show_deposit(update, context)
            
            elif data == 'account_withdraw':
                await self.show_withdraw(update, context)
            
            elif data == 'account_usage':
                await self.show_usage_stats(update, context)
            
            elif data == 'account_renew':
                await self.show_renew_options(update, context)
            
        except Exception as e:
            await query.answer(f"خطا: {str(e)}")

    async def handle_config_purchase(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت خرید کانفیگ"""
        query = update.callback_query
        data = query.data
        user_id = update.effective_user.id
        
        plan_index = int(data.split('_')[-1])
        plans = [
            {"name": "پلن اقتصادی", "volume": 5, "duration": 30, "price": 50000},
            {"name": "پلن استاندارد", "volume": 10, "duration": 30, "price": 90000},
            {"name": "پلن ویژه", "volume": 20, "duration": 30, "price": 160000}
        ]
        
        plan = plans[plan_index]
        
        # نمایش اطلاعات پرداخت
        payment_text = (
            f"💳 خرید {plan['name']}\n\n"
            f"💾 حجم: {plan['volume']} گیگابایت\n"
            f"⏱ مدت: {plan['duration']} روز\n"
            f"💰 قیمت: {plan['price']:,} تومان\n\n"
            "📌 روش پرداخت را انتخاب کنید:"
        )
        
        keyboard = [
            [InlineKeyboardButton("💳 پرداخت از موجودی", 
                                callback_data=f'payment_balance_{plan_index}')],
            [InlineKeyboardButton("💳 کارت به کارت", 
                                callback_data=f'payment_card_{plan_index}')],
            [InlineKeyboardButton("🔙 بازگشت", callback_data='buy_config')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(payment_text, reply_markup=reply_markup)

    async def show_deposit(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش صفحه افزایش موجودی"""
        query = update.callback_query
        
        amounts = [50000, 100000, 200000, 500000]
        
        deposit_text = (
            "💳 افزایش موجودی:\n\n"
            "لطفا مبلغ مورد نظر را انتخاب کنید:"
        )
        
        keyboard = []
        for amount in amounts:
            keyboard.append([
                InlineKeyboardButton(f"{amount:,} تومان", 
                                   callback_data=f'payment_deposit_{amount}')
            ])
        keyboard.append([InlineKeyboardButton("🔙 بازگشت", callback_data='account')])
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(deposit_text, reply_markup=reply_markup)

    async def show_withdraw(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش صفحه برداشت موجودی"""
        query = update.callback_query
        user_id = update.effective_user.id
        
        # دریافت تنظیمات برداشت
        settings = self.config.get_withdraw_settings()
        if not settings['enabled']:
            await query.answer("❌ امکان برداشت در حال حاضر غیرفعال است!")
            return
            
        # دریافت موجودی کاربر
        user = self.db.get_user(user_id)
        if user.balance < settings['min_amount']:
            await query.answer(
                f"❌ حداقل مبلغ برداشت {settings['min_amount']:,} تومان است!"
            )
            return
            
        withdraw_text = (
            "💰 برداشت موجودی:\n\n"
            f"💳 موجودی فعلی: {user.balance:,} تومان\n"
            f"📌 حداقل مبلغ برداشت: {settings['min_amount']:,} تومان\n\n"
            "لطفا مبلغ مورد نظر را وارد کنید:"
        )
        
        keyboard = [[InlineKeyboardButton("🔙 بازگشت", callback_data='account')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        context.user_data['action'] = 'withdraw'
        await query.edit_message_text(withdraw_text, reply_markup=reply_markup)

    async def show_usage_stats(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش آمار مصرف"""
        query = update.callback_query
        user_id = update.effective_user.id
        
        # دریافت کانفیگ‌های فعال
        configs = self.db.get_user_configs(user_id)
        if not configs:
            await query.answer("❌ شما هیچ کانفیگ فعالی ندارید!")
            return
            
        usage_text = "📊 گزارش مصرف:\n\n"
        keyboard = []
        
        for config in configs:
            if config.is_active:
                usage_text += f"🔰 {config.name}:\n"
                usage_text += f"💾 حجم مصرفی: {config.volume} گیگابایت\n"
                usage_text += f"⏱ زمان باقیمانده: {(config.expiry_date - datetime.utcnow()).days} روز\n\n"
                keyboard.append([
                    InlineKeyboardButton(f"📈 نمودار مصرف {config.name}", 
                                       callback_data=f'usage_graph_{config.id}')
                ])
        
        keyboard.append([InlineKeyboardButton("🔙 بازگشت", callback_data='account')])
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(usage_text, reply_markup=reply_markup)

    async def show_renew_options(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش گزینه‌های تمدید"""
        query = update.callback_query
        user_id = update.effective_user.id
        
        # دریافت کانفیگ‌های فعال
        configs = self.db.get_user_configs(user_id)
        if not configs:
            await query.answer("❌ شما هیچ کانفیگ فعالی ندارید!")
            return
            
        renew_text = "🔄 تمدید کانفیگ:\n\n"
        keyboard = []
        
        for config in configs:
            if config.is_active:
                renew_text += f"🔰 {config.name}:\n"
                renew_text += f"⏱ زمان باقیمانده: {(config.expiry_date - datetime.utcnow()).days} روز\n"
                renew_text += f"💰 هزینه تمدید: {config.price:,} تومان\n\n"
                keyboard.append([
                    InlineKeyboardButton(f"تمدید {config.name}", 
                                       callback_data=f'renew_{config.id}')
                ])
        
        keyboard.append([InlineKeyboardButton("🔙 بازگشت", callback_data='account')])
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(renew_text, reply_markup=reply_markup) 