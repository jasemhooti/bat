import os
import logging
from datetime import datetime

def setup_logger():
    """تنظیم لاگر"""
    # ایجاد دایرکتوری لاگ‌ها
    log_dir = 'logs'
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)
    
    # تنظیم نام فایل لاگ
    log_file = os.path.join(log_dir, f'bot_{datetime.now().strftime("%Y%m%d")}.log')
    
    # تنظیم فرمت لاگ
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # تنظیم هندلر فایل
    file_handler = logging.FileHandler(log_file, encoding='utf-8')
    file_handler.setFormatter(formatter)
    
    # تنظیم هندلر کنسول
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    
    # تنظیم لاگر اصلی
    logger = logging.getLogger('bot')
    logger.setLevel(logging.INFO)
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    return logger 