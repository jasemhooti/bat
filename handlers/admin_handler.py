from typing import Dict, Any
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes
from database import Database
from config import Config

class AdminHandler:
    def __init__(self, db: Database, config: Config):
        self.db = db
        self.config = config

    async def show_admin_panel(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش پنل مدیریت"""
        query = update.callback_query
        keyboard = [
            [InlineKeyboardButton("📊 آمار کلی", callback_data='admin_stats'),
             InlineKeyboardButton("👥 کاربران", callback_data='admin_users')],
            [InlineKeyboardButton("⚙️ تنظیمات", callback_data='admin_settings'),
             InlineKeyboardButton("💰 تراکنش‌ها", callback_data='admin_transactions')],
            [InlineKeyboardButton("🎮 مدیریت بازی", callback_data='admin_game'),
             InlineKeyboardButton("🔧 مدیریت پنل‌ها", callback_data='admin_panels')],
            [InlineKeyboardButton("🔙 بازگشت", callback_data='start')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            "👨‍💻 پنل مدیریت\n"
            "از منوی زیر بخش مورد نظر را انتخاب کنید:",
            reply_markup=reply_markup
        )

    async def handle_callback(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت کالبک‌های ادمین"""
        query = update.callback_query
        data = query.data

        try:
            if data == 'admin_stats':
                await self.show_stats(update, context)
            elif data == 'admin_users':
                await self.show_users(update, context)
            elif data == 'admin_settings':
                await self.show_settings(update, context)
            elif data == 'admin_transactions':
                await self.show_transactions(update, context)
            elif data == 'admin_game':
                await self.show_game_settings(update, context)
            elif data == 'admin_panels':
                await self.show_panels(update, context)
            elif data.startswith('admin_settings_'):
                await self.handle_settings(update, context)
            elif data.startswith('admin_panel_'):
                await self.handle_panel_settings(update, context)
        except Exception as e:
            await query.answer(f"خطا: {str(e)}")

    async def show_stats(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش آمار کلی"""
        query = update.callback_query
        
        # دریافت آمار
        total_users = len(self.db.session.query(self.db.User).all())
        active_configs = len(self.db.session.query(self.db.Config).filter_by(is_active=True).all())
        total_transactions = len(self.db.session.query(self.db.Transaction).all())
        total_games = len(self.db.session.query(self.db.Game).all())
        
        stats_text = (
            "📊 آمار کلی ربات:\n\n"
            f"👥 تعداد کل کاربران: {total_users}\n"
            f"🔰 کانفیگ‌های فعال: {active_configs}\n"
            f"💰 تعداد تراکنش‌ها: {total_transactions}\n"
            f"🎮 تعداد بازی‌ها: {total_games}"
        )
        
        keyboard = [[InlineKeyboardButton("🔙 بازگشت", callback_data='admin_panel')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(stats_text, reply_markup=reply_markup)

    async def show_users(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش لیست کاربران"""
        query = update.callback_query
        
        # دریافت کاربران
        users = self.db.session.query(self.db.User).all()
        
        users_text = "👥 لیست کاربران:\n\n"
        for user in users[:10]:  # نمایش 10 کاربر اول
            users_text += f"🆔 {user.user_id}"
            if user.username:
                users_text += f" (@{user.username})"
            users_text += f"\n💰 موجودی: {user.balance:,} تومان\n"
            users_text += f"📅 تاریخ عضویت: {user.join_date}\n\n"
        
        keyboard = [
            [InlineKeyboardButton("◀️ قبلی", callback_data='admin_users_prev'),
             InlineKeyboardButton("بعدی ▶️", callback_data='admin_users_next')],
            [InlineKeyboardButton("🔙 بازگشت", callback_data='admin_panel')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(users_text, reply_markup=reply_markup)

    async def show_settings(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش تنظیمات"""
        query = update.callback_query
        
        settings = {
            'channel': self.config.get_required_channel() or 'تنظیم نشده',
            'card': self.config.get_card_number() or 'تنظیم نشده',
            'auto_approve': '✅ فعال' if self.config.get_auto_approve_settings()['enabled'] else '❌ غیرفعال',
            'ticket': '✅ فعال' if self.config.get_ticket_enabled() else '❌ غیرفعال',
            'referral': '✅ فعال' if self.config.get_referral_settings()['enabled'] else '❌ غیرفعال'
        }
        
        settings_text = (
            "⚙️ تنظیمات ربات:\n\n"
            f"📢 کانال اجباری: {settings['channel']}\n"
            f"💳 شماره کارت: {settings['card']}\n"
            f"✅ تایید خودکار: {settings['auto_approve']}\n"
            f"🎫 سیستم تیکت: {settings['ticket']}\n"
            f"👥 سیستم زیرمجموعه: {settings['referral']}"
        )
        
        keyboard = [
            [InlineKeyboardButton("📢 تنظیم کانال", callback_data='admin_settings_channel'),
             InlineKeyboardButton("💳 تنظیم کارت", callback_data='admin_settings_card')],
            [InlineKeyboardButton("✅ تایید خودکار", callback_data='admin_settings_auto_approve'),
             InlineKeyboardButton("🎫 سیستم تیکت", callback_data='admin_settings_ticket')],
            [InlineKeyboardButton("👥 سیستم زیرمجموعه", callback_data='admin_settings_referral')],
            [InlineKeyboardButton("🔙 بازگشت", callback_data='admin_panel')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(settings_text, reply_markup=reply_markup)

    async def show_transactions(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش تراکنش‌ها"""
        query = update.callback_query
        
        # دریافت تراکنش‌ها
        transactions = self.db.session.query(self.db.Transaction).order_by(self.db.Transaction.created_at.desc()).all()
        
        trans_text = "💰 لیست تراکنش‌ها:\n\n"
        for trans in transactions[:10]:  # نمایش 10 تراکنش اخیر
            trans_text += f"🆔 کاربر: {trans.user.user_id}\n"
            trans_text += f"💵 مبلغ: {trans.amount:,} تومان\n"
            trans_text += f"📝 نوع: {trans.type}\n"
            trans_text += f"📊 وضعیت: {trans.status}\n"
            trans_text += f"📅 تاریخ: {trans.created_at}\n\n"
        
        keyboard = [
            [InlineKeyboardButton("◀️ قبلی", callback_data='admin_trans_prev'),
             InlineKeyboardButton("بعدی ▶️", callback_data='admin_trans_next')],
            [InlineKeyboardButton("🔙 بازگشت", callback_data='admin_panel')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(trans_text, reply_markup=reply_markup)

    async def show_game_settings(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش تنظیمات بازی"""
        query = update.callback_query
        
        settings = self.config.get_game_settings()
        
        game_text = (
            "🎮 تنظیمات بازی:\n\n"
            f"🎲 بازی تک نفره: {'✅ فعال' if settings['single_player_enabled'] else '❌ غیرفعال'}\n"
            f"💰 حداقل شرط: {settings['min_bet']:,} تومان\n"
            f"💵 حداکثر شرط: {settings['max_bet']:,} تومان\n"
            f"🎯 بازی رایگان: {'✅ فعال' if settings['free_enabled'] else '❌ غیرفعال'}"
        )
        
        keyboard = [
            [InlineKeyboardButton("🎲 بازی تک نفره", callback_data='admin_game_single'),
             InlineKeyboardButton("💰 تنظیم مبالغ", callback_data='admin_game_bet')],
            [InlineKeyboardButton("🎯 بازی رایگان", callback_data='admin_game_free')],
            [InlineKeyboardButton("🔙 بازگشت", callback_data='admin_panel')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(game_text, reply_markup=reply_markup)

    async def show_panels(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش پنل‌های X-UI"""
        query = update.callback_query
        
        panels = self.config.get_panel_settings()
        
        panels_text = "🔧 پنل‌های X-UI:\n\n"
        for i, panel in enumerate(panels):
            panels_text += f"📍 پنل #{i+1}:\n"
            panels_text += f"🔗 آدرس: {panel['url']}\n"
            panels_text += f"👤 نام کاربری: {panel['username']}\n\n"
        
        keyboard = [
            [InlineKeyboardButton("➕ افزودن پنل", callback_data='admin_panel_add')],
            [InlineKeyboardButton("❌ حذف پنل", callback_data='admin_panel_remove'),
             InlineKeyboardButton("✏️ ویرایش پنل", callback_data='admin_panel_edit')],
            [InlineKeyboardButton("🔙 بازگشت", callback_data='admin_panel')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(panels_text, reply_markup=reply_markup)

    async def handle_settings(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت تنظیمات"""
        query = update.callback_query
        data = query.data
        
        if data == 'admin_settings_channel':
            context.user_data['admin_action'] = 'set_channel'
            await query.edit_message_text(
                "📢 لطفا نام کانال را بدون @ وارد کنید:\n"
                "برای غیرفعال کردن عدد 0 را وارد کنید.",
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("🔙 بازگشت", callback_data='admin_settings')
                ]])
            )
        
        elif data == 'admin_settings_card':
            context.user_data['admin_action'] = 'set_card'
            await query.edit_message_text(
                "💳 لطفا شماره کارت را وارد کنید:",
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("🔙 بازگشت", callback_data='admin_settings')
                ]])
            )
        
        elif data == 'admin_settings_auto_approve':
            settings = self.config.get_auto_approve_settings()
            self.config.set_auto_approve_settings(not settings['enabled'], settings['time'])
            await self.show_settings(update, context)
        
        elif data == 'admin_settings_ticket':
            self.config.set_ticket_enabled(not self.config.get_ticket_enabled())
            await self.show_settings(update, context)
        
        elif data == 'admin_settings_referral':
            settings = self.config.get_referral_settings()
            self.config.set_referral_settings(not settings['enabled'], settings['percentage'])
            await self.show_settings(update, context)

    async def handle_panel_settings(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت تنظیمات پنل"""
        query = update.callback_query
        data = query.data
        
        if data == 'admin_panel_add':
            context.user_data['admin_action'] = 'add_panel'
            await query.edit_message_text(
                "🔧 افزودن پنل جدید\n\n"
                "لطفا اطلاعات پنل را به صورت زیر وارد کنید:\n"
                "آدرس|نام کاربری|رمز عبور\n\n"
                "مثال:\n"
                "https://panel.example.com|admin|password",
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("🔙 بازگشت", callback_data='admin_panels')
                ]])
            )
        
        elif data == 'admin_panel_remove':
            panels = self.config.get_panel_settings()
            if not panels:
                await query.answer("❌ هیچ پنلی موجود نیست!")
                return
                
            keyboard = []
            for i, panel in enumerate(panels):
                keyboard.append([
                    InlineKeyboardButton(f"پنل #{i+1} - {panel['url']}", 
                                       callback_data=f'admin_panel_remove_{i}')
                ])
            keyboard.append([InlineKeyboardButton("🔙 بازگشت", callback_data='admin_panels')])
            
            await query.edit_message_text(
                "❌ لطفا پنل مورد نظر برای حذف را انتخاب کنید:",
                reply_markup=InlineKeyboardMarkup(keyboard)
            )
        
        elif data.startswith('admin_panel_remove_'):
            index = int(data.split('_')[-1])
            self.config.remove_panel(index)
            await query.answer("✅ پنل با موفقیت حذف شد!")
            await self.show_panels(update, context)
        
        elif data == 'admin_panel_edit':
            panels = self.config.get_panel_settings()
            if not panels:
                await query.answer("❌ هیچ پنلی موجود نیست!")
                return
                
            keyboard = []
            for i, panel in enumerate(panels):
                keyboard.append([
                    InlineKeyboardButton(f"پنل #{i+1} - {panel['url']}", 
                                       callback_data=f'admin_panel_edit_{i}')
                ])
            keyboard.append([InlineKeyboardButton("🔙 بازگشت", callback_data='admin_panels')])
            
            await query.edit_message_text(
                "✏️ لطفا پنل مورد نظر برای ویرایش را انتخاب کنید:",
                reply_markup=InlineKeyboardMarkup(keyboard)
            )
        
        elif data.startswith('admin_panel_edit_'):
            index = int(data.split('_')[-1])
            context.user_data['admin_action'] = f'edit_panel_{index}'
            await query.edit_message_text(
                "🔧 ویرایش پنل\n\n"
                "لطفا اطلاعات جدید پنل را به صورت زیر وارد کنید:\n"
                "آدرس|نام کاربری|رمز عبور\n\n"
                "مثال:\n"
                "https://panel.example.com|admin|password",
                reply_markup=InlineKeyboardMarkup([[
                    InlineKeyboardButton("🔙 بازگشت", callback_data='admin_panels')
                ]])
            ) 