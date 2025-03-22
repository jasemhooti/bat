from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes
from database import Database
from config import Config

class PaymentHandler:
    def __init__(self, db: Database, config: Config):
        self.db = db
        self.config = config

    async def handle_callback(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت کالبک‌های پرداخت"""
        query = update.callback_query
        data = query.data
        user_id = update.effective_user.id
        
        try:
            if data.startswith('payment_balance_'):
                await self.handle_balance_payment(update, context)
            
            elif data.startswith('payment_card_'):
                await self.handle_card_payment(update, context)
            
            elif data.startswith('payment_deposit_'):
                await self.handle_deposit(update, context)
            
            elif data == 'payment_verify':
                await self.verify_payment(update, context)
            
            elif data == 'payment_cancel':
                await self.cancel_payment(update, context)
                
        except Exception as e:
            await query.answer(f"خطا: {str(e)}")

    async def handle_balance_payment(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت پرداخت از موجودی"""
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
        
        # بررسی موجودی کاربر
        user = self.db.get_user(user_id)
        if user.balance < plan['price']:
            await query.answer("❌ موجودی شما کافی نیست!")
            return
            
        # کسر موجودی و ثبت تراکنش
        self.db.update_balance(user_id, -plan['price'])
        transaction = self.db.add_transaction(
            user_id=user_id,
            amount=plan['price'],
            type='config_purchase',
            description=f"خرید {plan['name']}"
        )
        
        # ایجاد کانفیگ
        config = self.db.add_config(
            user_id=user_id,
            name=plan['name'],
            data="",  # کانفیگ خالی - بعدا پر می‌شود
            volume=plan['volume'],
            duration=plan['duration'],
            price=plan['price']
        )
        
        # ارسال به کانال گزارشات
        report_settings = self.config.get_report_settings()
        if report_settings['enabled'] and report_settings['channel']:
            report_text = (
                "🛍 خرید جدید:\n\n"
                f"👤 کاربر: {user_id}\n"
                f"📍 پلن: {plan['name']}\n"
                f"💰 مبلغ: {plan['price']:,} تومان\n"
                f"💳 روش پرداخت: کسر از موجودی\n"
                f"📅 تاریخ: {datetime.now()}"
            )
            await context.bot.send_message(
                chat_id=report_settings['channel'],
                text=report_text
            )
        
        # ارسال پیام موفقیت
        success_text = (
            "✅ خرید با موفقیت انجام شد!\n\n"
            f"📍 پلن: {plan['name']}\n"
            f"💾 حجم: {plan['volume']} گیگابایت\n"
            f"⏱ مدت: {plan['duration']} روز\n"
            f"💰 مبلغ پرداختی: {plan['price']:,} تومان\n\n"
            "🔄 در حال ساخت کانفیگ..."
        )
        
        keyboard = [[InlineKeyboardButton("🔙 بازگشت به منو", callback_data='start')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(success_text, reply_markup=reply_markup)
        
        # ساخت و ارسال کانفیگ
        await self.create_and_send_config(update, context, config)

    async def handle_card_payment(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت پرداخت کارت به کارت"""
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
        
        # دریافت شماره کارت
        card_number = self.config.get_card_number()
        if not card_number:
            await query.answer("❌ شماره کارت تنظیم نشده است!")
            return
            
        payment_text = (
            f"💳 پرداخت کارت به کارت\n\n"
            f"📍 پلن: {plan['name']}\n"
            f"💰 مبلغ: {plan['price']:,} تومان\n\n"
            f"📌 شماره کارت:\n"
            f"`{card_number}`\n"
            "به نام: ...\n\n"
            "پس از واریز، رسید پرداخت را ارسال کنید."
        )
        
        keyboard = [
            [InlineKeyboardButton("✅ ارسال رسید", callback_data='payment_verify')],
            [InlineKeyboardButton("❌ انصراف", callback_data='payment_cancel')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        # ذخیره اطلاعات پرداخت
        context.user_data['payment'] = {
            'plan_index': plan_index,
            'amount': plan['price'],
            'method': 'card',
            'status': 'pending'
        }
        
        await query.edit_message_text(
            payment_text, 
            reply_markup=reply_markup,
            parse_mode='Markdown'
        )

    async def handle_deposit(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت افزایش موجودی"""
        query = update.callback_query
        data = query.data
        user_id = update.effective_user.id
        
        amount = int(data.split('_')[-1])
        
        # دریافت شماره کارت
        card_number = self.config.get_card_number()
        if not card_number:
            await query.answer("❌ شماره کارت تنظیم نشده است!")
            return
            
        payment_text = (
            "💳 افزایش موجودی\n\n"
            f"💰 مبلغ: {amount:,} تومان\n\n"
            f"📌 شماره کارت:\n"
            f"`{card_number}`\n"
            "به نام: ...\n\n"
            "پس از واریز، رسید پرداخت را ارسال کنید."
        )
        
        keyboard = [
            [InlineKeyboardButton("✅ ارسال رسید", callback_data='payment_verify')],
            [InlineKeyboardButton("❌ انصراف", callback_data='payment_cancel')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        # ذخیره اطلاعات پرداخت
        context.user_data['payment'] = {
            'amount': amount,
            'method': 'deposit',
            'status': 'pending'
        }
        
        await query.edit_message_text(
            payment_text, 
            reply_markup=reply_markup,
            parse_mode='Markdown'
        )

    async def verify_payment(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """تایید پرداخت"""
        query = update.callback_query
        user_id = update.effective_user.id
        
        if 'payment' not in context.user_data:
            await query.answer("❌ اطلاعات پرداخت یافت نشد!")
            return
            
        payment = context.user_data['payment']
        if payment['status'] != 'pending':
            await query.answer("❌ این پرداخت قبلا پردازش شده است!")
            return
            
        verify_text = (
            "📱 لطفا رسید پرداخت را ارسال کنید.\n\n"
            "✅ رسید باید به صورت عکس باشد."
        )
        
        keyboard = [[InlineKeyboardButton("❌ انصراف", callback_data='payment_cancel')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        context.user_data['action'] = 'verify_payment'
        await query.edit_message_text(verify_text, reply_markup=reply_markup)

    async def cancel_payment(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """لغو پرداخت"""
        query = update.callback_query
        
        if 'payment' in context.user_data:
            del context.user_data['payment']
        if 'action' in context.user_data:
            del context.user_data['action']
            
        await query.edit_message_text(
            "❌ پرداخت لغو شد.",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("🔙 بازگشت به منو", callback_data='start')
            ]])
        )

    async def create_and_send_config(self, update: Update, context: ContextTypes.DEFAULT_TYPE, config):
        """ساخت و ارسال کانفیگ"""
        query = update.callback_query
        user_id = update.effective_user.id
        
        try:
            # ساخت کانفیگ در پنل
            panels = self.config.get_panel_settings()
            if not panels:
                raise Exception("❌ هیچ پنلی تنظیم نشده است!")
                
            # انتخاب یک پنل
            panel = panels[0]  # فعلا اولین پنل
            
            # ساخت کانفیگ در پنل
            config_data = "..."  # اینجا باید کانفیگ ساخته شود
            
            # بروزرسانی کانفیگ در دیتابیس
            config.data = config_data
            self.db.session.commit()
            
            # ارسال کانفیگ به کاربر
            config_text = (
                "✅ کانفیگ شما با موفقیت ساخته شد!\n\n"
                f"📍 نام: {config.name}\n"
                f"💾 حجم: {config.volume} گیگابایت\n"
                f"⏱ مدت: {(config.expiry_date - datetime.utcnow()).days} روز\n\n"
                "📌 کانفیگ:\n"
                f"`{config_data}`"
            )
            
            keyboard = [[InlineKeyboardButton("🔙 بازگشت به منو", callback_data='start')]]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await query.edit_message_text(
                config_text,
                reply_markup=reply_markup,
                parse_mode='Markdown'
            )
            
        except Exception as e:
            error_text = (
                "❌ خطا در ساخت کانفیگ!\n\n"
                "لطفا با پشتیبانی تماس بگیرید."
            )
            
            keyboard = [[InlineKeyboardButton("🔙 بازگشت به منو", callback_data='start')]]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await query.edit_message_text(error_text, reply_markup=reply_markup) 