import os
from typing import Optional, Dict, Any
import json

class Config:
    def __init__(self):
        self.config_file = 'config.json'
        self.default_config = {
            'required_channel': None,  # کانال اجباری
            'card_number': None,  # شماره کارت
            'auto_approve_time': 5,  # زمان تایید خودکار (دقیقه)
            'auto_approve_enabled': True,  # فعال بودن تایید خودکار
            'ticket_enabled': True,  # فعال بودن تیکت
            'report_channel': None,  # کانال گزارشات
            'report_enabled': True,  # فعال بودن گزارشات
            'backup_channel': None,  # کانال پشتیبان‌گیری
            'auto_backup_enabled': True,  # فعال بودن پشتیبان‌گیری خودکار
            'referral_enabled': True,  # فعال بودن سیستم زیرمجموعه‌گیری
            'referral_percentage': 10,  # درصد پورسانت زیرمجموعه
            'min_withdraw': 50000,  # حداقل مبلغ برداشت (تومان)
            'withdraw_enabled': True,  # فعال بودن برداشت
            'game_settings': {
                'single_player_enabled': True,  # فعال بودن بازی تک نفره
                'min_bet': 500,  # حداقل شرط (تومان)
                'max_bet': 5000000,  # حداکثر شرط (تومان)
                'free_enabled': False  # رایگان بودن بازی
            },
            'panel_settings': []  # تنظیمات پنل‌های X-UI
        }
        self.load_config()

    def load_config(self):
        """بارگذاری تنظیمات از فایل"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    self.config = json.load(f)
            else:
                self.config = self.default_config.copy()
                self.save_config()
        except Exception as e:
            print(f"Error loading config: {e}")
            self.config = self.default_config.copy()

    def save_config(self):
        """ذخیره تنظیمات در فایل"""
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=4, ensure_ascii=False)
        except Exception as e:
            print(f"Error saving config: {e}")

    def get_required_channel(self) -> Optional[str]:
        """دریافت کانال اجباری"""
        return self.config.get('required_channel')

    def set_required_channel(self, channel: Optional[str]):
        """تنظیم کانال اجباری"""
        self.config['required_channel'] = channel
        self.save_config()

    def get_card_number(self) -> Optional[str]:
        """دریافت شماره کارت"""
        return self.config.get('card_number')

    def set_card_number(self, card_number: str):
        """تنظیم شماره کارت"""
        self.config['card_number'] = card_number
        self.save_config()

    def get_auto_approve_settings(self) -> Dict[str, Any]:
        """دریافت تنظیمات تایید خودکار"""
        return {
            'enabled': self.config.get('auto_approve_enabled', True),
            'time': self.config.get('auto_approve_time', 5)
        }

    def set_auto_approve_settings(self, enabled: bool, time: int):
        """تنظیم تنظیمات تایید خودکار"""
        self.config['auto_approve_enabled'] = enabled
        self.config['auto_approve_time'] = time
        self.save_config()

    def get_ticket_enabled(self) -> bool:
        """دریافت وضعیت تیکت"""
        return self.config.get('ticket_enabled', True)

    def set_ticket_enabled(self, enabled: bool):
        """تنظیم وضعیت تیکت"""
        self.config['ticket_enabled'] = enabled
        self.save_config()

    def get_report_settings(self) -> Dict[str, Any]:
        """دریافت تنظیمات گزارشات"""
        return {
            'enabled': self.config.get('report_enabled', True),
            'channel': self.config.get('report_channel')
        }

    def set_report_settings(self, enabled: bool, channel: Optional[str]):
        """تنظیم تنظیمات گزارشات"""
        self.config['report_enabled'] = enabled
        self.config['report_channel'] = channel
        self.save_config()

    def get_backup_settings(self) -> Dict[str, Any]:
        """دریافت تنظیمات پشتیبان‌گیری"""
        return {
            'enabled': self.config.get('auto_backup_enabled', True),
            'channel': self.config.get('backup_channel')
        }

    def set_backup_settings(self, enabled: bool, channel: Optional[str]):
        """تنظیم تنظیمات پشتیبان‌گیری"""
        self.config['auto_backup_enabled'] = enabled
        self.config['backup_channel'] = channel
        self.save_config()

    def get_referral_settings(self) -> Dict[str, Any]:
        """دریافت تنظیمات زیرمجموعه‌گیری"""
        return {
            'enabled': self.config.get('referral_enabled', True),
            'percentage': self.config.get('referral_percentage', 10)
        }

    def set_referral_settings(self, enabled: bool, percentage: int):
        """تنظیم تنظیمات زیرمجموعه‌گیری"""
        self.config['referral_enabled'] = enabled
        self.config['referral_percentage'] = percentage
        self.save_config()

    def get_withdraw_settings(self) -> Dict[str, Any]:
        """دریافت تنظیمات برداشت"""
        return {
            'enabled': self.config.get('withdraw_enabled', True),
            'min_amount': self.config.get('min_withdraw', 50000)
        }

    def set_withdraw_settings(self, enabled: bool, min_amount: int):
        """تنظیم تنظیمات برداشت"""
        self.config['withdraw_enabled'] = enabled
        self.config['min_withdraw'] = min_amount
        self.save_config()

    def get_game_settings(self) -> Dict[str, Any]:
        """دریافت تنظیمات بازی"""
        return self.config.get('game_settings', self.default_config['game_settings'])

    def set_game_settings(self, settings: Dict[str, Any]):
        """تنظیم تنظیمات بازی"""
        self.config['game_settings'] = settings
        self.save_config()

    def get_panel_settings(self) -> list:
        """دریافت تنظیمات پنل‌ها"""
        return self.config.get('panel_settings', [])

    def add_panel(self, url: str, username: str, password: str):
        """اضافه کردن پنل جدید"""
        self.config['panel_settings'].append({
            'url': url,
            'username': username,
            'password': password
        })
        self.save_config()

    def remove_panel(self, index: int):
        """حذف پنل"""
        if 0 <= index < len(self.config['panel_settings']):
            del self.config['panel_settings'][index]
            self.save_config()

    def update_panel(self, index: int, url: str, username: str, password: str):
        """بروزرسانی پنل"""
        if 0 <= index < len(self.config['panel_settings']):
            self.config['panel_settings'][index] = {
                'url': url,
                'username': username,
                'password': password
            }
            self.save_config() 