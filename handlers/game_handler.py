import random
from datetime import datetime
from typing import Optional, Dict, Any
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes
from database import Database
from config import Config

class GameHandler:
    def __init__(self, db: Database, config: Config):
        self.db = db
        self.config = config

    async def show_game_menu(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش منوی بازی"""
        query = update.callback_query
        
        settings = self.config.get_game_settings()
        
        game_text = (
            "🎮 منوی بازی:\n\n"
            "🎲 بازی حدس عدد\n"
            "- شما یک عدد بین 1 تا 6 انتخاب می‌کنید\n"
            "- حریف باید عدد شما را حدس بزند\n"
            "- برنده جایزه را دریافت می‌کند!\n\n"
            f"💰 حداقل شرط: {settings['min_bet']:,} تومان\n"
            f"💵 حداکثر شرط: {settings['max_bet']:,} تومان"
        )
        
        keyboard = [
            [InlineKeyboardButton("🎲 بازی تک نفره", callback_data='game_single')],
            [InlineKeyboardButton("👥 بازی دو نفره", callback_data='game_multi')],
            [InlineKeyboardButton("📊 آمار بازی‌ها", callback_data='game_stats')],
            [InlineKeyboardButton("🔙 بازگشت", callback_data='start')]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(game_text, reply_markup=reply_markup)

    async def handle_callback(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت کالبک‌های بازی"""
        query = update.callback_query
        data = query.data
        user_id = update.effective_user.id
        
        try:
            if data == 'game_single':
                await self.start_single_game(update, context)
            
            elif data == 'game_multi':
                await self.start_multi_game(update, context)
            
            elif data == 'game_stats':
                await self.show_game_stats(update, context)
            
            elif data.startswith('game_bet_'):
                await self.handle_bet(update, context)
            
            elif data.startswith('game_number_'):
                await self.handle_number_selection(update, context)
            
            elif data == 'game_guess':
                await self.handle_guess(update, context)
            
            elif data == 'game_cancel':
                await self.cancel_game(update, context)
                
        except Exception as e:
            await query.answer(f"خطا: {str(e)}")

    async def start_single_game(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """شروع بازی تک نفره"""
        query = update.callback_query
        user_id = update.effective_user.id
        
        settings = self.config.get_game_settings()
        if not settings['single_player_enabled']:
            await query.answer("❌ بازی تک نفره در حال حاضر غیرفعال است!")
            return
            
        # نمایش مبالغ شرط
        bet_text = (
            "🎲 بازی تک نفره\n\n"
            "💰 لطفا مبلغ شرط را انتخاب کنید:"
        )
        
        keyboard = []
        bet_amounts = [
            settings['min_bet'],
            settings['min_bet'] * 2,
            settings['min_bet'] * 5,
            settings['min_bet'] * 10
        ]
        
        for amount in bet_amounts:
            if amount <= settings['max_bet']:
                keyboard.append([
                    InlineKeyboardButton(f"{amount:,} تومان", 
                                       callback_data=f'game_bet_single_{amount}')
                ])
        
        keyboard.append([InlineKeyboardButton("🔙 بازگشت", callback_data='game')])
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(bet_text, reply_markup=reply_markup)

    async def start_multi_game(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """شروع بازی دو نفره"""
        query = update.callback_query
        user_id = update.effective_user.id
        
        settings = self.config.get_game_settings()
        
        # نمایش مبالغ شرط
        bet_text = (
            "👥 بازی دو نفره\n\n"
            "💰 لطفا مبلغ شرط را انتخاب کنید:"
        )
        
        keyboard = []
        bet_amounts = [
            settings['min_bet'],
            settings['min_bet'] * 2,
            settings['min_bet'] * 5,
            settings['min_bet'] * 10
        ]
        
        for amount in bet_amounts:
            if amount <= settings['max_bet']:
                keyboard.append([
                    InlineKeyboardButton(f"{amount:,} تومان", 
                                       callback_data=f'game_bet_multi_{amount}')
                ])
        
        keyboard.append([InlineKeyboardButton("🔙 بازگشت", callback_data='game')])
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(bet_text, reply_markup=reply_markup)

    async def handle_bet(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت انتخاب مبلغ شرط"""
        query = update.callback_query
        data = query.data
        user_id = update.effective_user.id
        
        game_type, amount = data.split('_')[2:]
        amount = int(amount)
        
        # بررسی موجودی کاربر
        user = self.db.get_user(user_id)
        if user.balance < amount:
            await query.answer("❌ موجودی شما کافی نیست!")
            return
            
        # ایجاد بازی جدید
        game = self.db.create_game(
            user_id=user_id,
            game_type=game_type,
            bet_amount=amount
        )
        
        if game_type == 'single':
            # بازی تک نفره
            number_text = (
                "🎲 انتخاب عدد\n\n"
                "لطفا یک عدد بین 1 تا 6 انتخاب کنید:"
            )
            
            keyboard = []
            row = []
            for i in range(1, 7):
                row.append(InlineKeyboardButton(str(i), 
                                              callback_data=f'game_number_{game.id}_{i}'))
                if len(row) == 3:
                    keyboard.append(row)
                    row = []
            if row:
                keyboard.append(row)
                
            keyboard.append([InlineKeyboardButton("❌ انصراف", callback_data='game_cancel')])
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await query.edit_message_text(number_text, reply_markup=reply_markup)
            
        else:
            # بازی دو نفره
            await self.create_multi_game(update, context, game)

    async def handle_number_selection(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت انتخاب عدد"""
        query = update.callback_query
        data = query.data
        user_id = update.effective_user.id
        
        game_id, number = map(int, data.split('_')[2:])
        
        # دریافت بازی
        game = self.db.session.query(self.db.Game).get(game_id)
        if not game or game.user_id != user_id:
            await query.answer("❌ بازی یافت نشد!")
            return
            
        # ذخیره عدد انتخابی
        game.game_data = {'selected_number': number}
        self.db.session.commit()
        
        if game.game_type == 'single':
            # بازی با ربات
            bot_guess = random.randint(1, 6)
            
            result_text = (
                "🎲 نتیجه بازی:\n\n"
                f"عدد شما: {number}\n"
                f"حدس ربات: {bot_guess}\n\n"
            )
            
            if bot_guess == number:
                # برد ربات
                game.result = 'lose'
                result_text += "❌ متاسفانه باختید!"
            else:
                # برد کاربر
                game.result = 'win'
                self.db.update_balance(user_id, game.bet_amount * 2)
                result_text += "🎉 تبریک! شما برنده شدید!"
                
            game.status = 'completed'
            self.db.session.commit()
            
            keyboard = [[InlineKeyboardButton("🔙 بازگشت", callback_data='game')]]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            await query.edit_message_text(result_text, reply_markup=reply_markup)
            
        else:
            # بازی دو نفره
            await self.wait_for_opponent(update, context, game)

    async def create_multi_game(self, update: Update, context: ContextTypes.DEFAULT_TYPE, game):
        """ایجاد بازی دو نفره"""
        query = update.callback_query
        
        # ایجاد لینک دعوت
        invite_link = f"https://t.me/{context.bot.username}?start=game_{game.id}"
        
        invite_text = (
            "👥 بازی دو نفره\n\n"
            f"💰 مبلغ شرط: {game.bet_amount:,} تومان\n\n"
            "🔗 لینک دعوت از حریف:\n"
            f"`{invite_link}`\n\n"
            "منتظر پیوستن حریف..."
        )
        
        keyboard = [[InlineKeyboardButton("❌ انصراف", callback_data='game_cancel')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(
            invite_text,
            reply_markup=reply_markup,
            parse_mode='Markdown'
        )

    async def wait_for_opponent(self, update: Update, context: ContextTypes.DEFAULT_TYPE, game):
        """انتظار برای حریف"""
        query = update.callback_query
        
        wait_text = (
            "👥 بازی دو نفره\n\n"
            f"💰 مبلغ شرط: {game.bet_amount:,} تومان\n"
            f"🎲 عدد انتخابی شما: {game.game_data['selected_number']}\n\n"
            "در انتظار حدس حریف..."
        )
        
        keyboard = [[InlineKeyboardButton("❌ انصراف", callback_data='game_cancel')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(wait_text, reply_markup=reply_markup)

    async def handle_guess(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """مدیریت حدس عدد"""
        query = update.callback_query
        data = query.data
        user_id = update.effective_user.id
        
        if 'game' not in context.user_data:
            await query.answer("❌ بازی یافت نشد!")
            return
            
        game = context.user_data['game']
        guess = int(data.split('_')[-1])
        
        # بررسی حدس
        if guess == game.game_data['selected_number']:
            # حدس درست
            game.result = 'win'
            self.db.update_balance(user_id, game.bet_amount * 2)
            result_text = "🎉 تبریک! حدس شما درست بود!"
        else:
            # حدس اشتباه
            game.result = 'lose'
            result_text = "❌ متاسفانه حدس شما اشتباه بود!"
            
        game.status = 'completed'
        self.db.session.commit()
        
        keyboard = [[InlineKeyboardButton("🔙 بازگشت", callback_data='game')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(result_text, reply_markup=reply_markup)

    async def cancel_game(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """لغو بازی"""
        query = update.callback_query
        user_id = update.effective_user.id
        
        if 'game' in context.user_data:
            game = context.user_data['game']
            
            # برگرداندن نصف مبلغ شرط
            self.db.update_balance(user_id, game.bet_amount / 2)
            
            game.status = 'cancelled'
            self.db.session.commit()
            
            del context.user_data['game']
            
        await query.edit_message_text(
            "❌ بازی لغو شد.",
            reply_markup=InlineKeyboardMarkup([[
                InlineKeyboardButton("🔙 بازگشت", callback_data='game')
            ]])
        )

    async def show_game_stats(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """نمایش آمار بازی‌ها"""
        query = update.callback_query
        user_id = update.effective_user.id
        
        # دریافت آمار
        stats = self.db.get_user_stats(user_id)
        
        stats_text = (
            "📊 آمار بازی‌های شما:\n\n"
            f"🎮 تعداد کل بازی‌ها: {stats['total_games']}\n"
            f"✅ برد: {stats['wins']}\n"
            f"⭕️ مساوی: {stats['draws']}\n"
            f"❌ باخت: {stats['losses']}\n\n"
            f"💰 مجموع برد: {stats['total_win_amount']:,} تومان\n"
            f"💸 مجموع باخت: {stats['total_lose_amount']:,} تومان"
        )
        
        keyboard = [[InlineKeyboardButton("🔙 بازگشت", callback_data='game')]]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        await query.edit_message_text(stats_text, reply_markup=reply_markup) 