# ربات تلگرام NetBox

این یک ربات تلگرام است که با استفاده از Python و کتابخانه python-telegram-bot ساخته شده است.

## ویژگی‌ها

- پشتیبانی از وب‌هوک و پولینگ
- ذخیره‌سازی اطلاعات در PostgreSQL
- سیستم لاگینگ
- مدیریت کاربران و پیام‌ها
- رابط کاربری با دکمه‌های اینلاین
- ارسال پیام به ادمین در زمان نصب و بروزرسانی

## پیش‌نیازها

- Python 3.8 یا بالاتر
- PostgreSQL
- Nginx (برای وب‌هوک)
- Let's Encrypt SSL (برای وب‌هوک)

## نصب

1. کلون کردن مخزن:
```bash
git clone https://github.com/yourusername/netbox-bot.git
cd netbox-bot
```

2. اجرای اسکریپت نصب:
```bash
sudo bash install.sh
```

3. انتخاب گزینه 1 برای نصب

4. وارد کردن اطلاعات مورد نیاز:
- توکن ربات
- شناسه ادمین
- آدرس IP سرور
- نام کاربری دیتابیس
- رمز عبور دیتابیس

## تنظیم وب‌هوک

1. اجرای مجدد اسکریپت نصب:
```bash
sudo bash install.sh
```

2. انتخاب گزینه 4 برای تنظیم وب‌هوک

3. وارد کردن اطلاعات مورد نیاز:
- آدرس IP سرور
- پورت وب‌هوک (پیش‌فرض: 8443)

## بروزرسانی

برای بروزرسانی ربات:

```bash
sudo bash install.sh
# انتخاب گزینه 2
```

## حذف

برای حذف ربات:

```bash
sudo bash install.sh
# انتخاب گزینه 3
```

## ساختار پروژه

```
netbox-bot/
├── bot.py              # کد اصلی ربات
├── database.py         # مدیریت دیتابیس
├── install.sh          # اسکریپت نصب
├── requirements.txt    # پکیج‌های مورد نیاز
├── utils/
│   ├── db_setup.py    # تنظیم دیتابیس
│   └── logger.py      # تنظیم لاگر
└── logs/              # فایل‌های لاگ
```

## تنظیمات

تنظیمات ربات در فایل `.env` ذخیره می‌شود:

```
BOT_TOKEN=your_bot_token
ADMIN_ID=your_admin_id
DATABASE_URL=postgresql://user:pass@localhost/dbname
WEBHOOK_MODE=webhook
WEBHOOK_URL=https://your-domain.com
WEBHOOK_PORT=8443
```

## لاگ‌ها

لاگ‌های ربات در دایرکتوری `logs` ذخیره می‌شوند و شامل اطلاعات زیر هستند:
- زمان اجرای دستورات
- خطاها و هشدارها
- اطلاعات کاربران
- وضعیت اتصال به دیتابیس

## پشتیبانی

برای ارتباط با پشتیبانی:
- ایمیل: support@example.com
- تلگرام: @support

## مجوز

این پروژه تحت مجوز MIT منتشر شده است. 