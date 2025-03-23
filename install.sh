#!/bin/bash

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# تابع ارسال پیام به تلگرام
send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${ADMIN_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML" > /dev/null
}

# تابع نصب
install() {
    echo -e "${YELLOW}شروع نصب ربات NetBox...${NC}"
    
    # دریافت اطلاعات
    read -p "لطفا توکن ربات را وارد کنید: " BOT_TOKEN
    read -p "لطفا شناسه ادمین را وارد کنید: " ADMIN_ID
    read -p "لطفا نام کاربری دیتابیس را وارد کنید: " DB_USER
    read -p "لطفا رمز عبور دیتابیس را وارد کنید: " DB_PASS
    read -p "لطفا دامنه یا IP سرور را وارد کنید: " DOMAIN
    read -p "لطفا پورت وب‌هوک را وارد کنید (پیش‌فرض: 8443): " WEBHOOK_PORT
    WEBHOOK_PORT=${WEBHOOK_PORT:-8443}
    
    # حذف فایل‌های قبلی
    rm -rf /opt/netbox
    rm -f /etc/nginx/sites-enabled/netbox
    rm -f /etc/systemd/system/netbox.service
    
    # ایجاد دایرکتوری‌ها
    mkdir -p /opt/netbox
    mkdir -p /opt/netbox/utils
    mkdir -p /opt/netbox/pay
    mkdir -p /opt/netbox/phpqrcode
    mkdir -p /opt/netbox/settings
    mkdir -p /opt/netbox/assets
    mkdir -p /opt/netbox/backups
    
    # ایجاد فایل‌ها
    cat > /opt/netbox/bot.py << 'EOL'
import os
import logging
import asyncpg
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
from dotenv import load_dotenv

# تنظیم لاگر
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# لود کردن متغیرهای محیطی
load_dotenv()

# تنظیمات دیتابیس
DB_CONFIG = {
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASS'),
    'host': 'localhost',
    'database': 'netbox_db'
}

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /start"""
    user = update.effective_user
    async with asyncpg.create_pool(**DB_CONFIG) as pool:
        await pool.execute('''
            INSERT INTO users (user_id, username, first_name)
            VALUES ($1, $2, $3)
            ON CONFLICT (user_id) DO UPDATE
            SET username = $2, first_name = $3
        ''', user.id, user.username, user.first_name)
    
    await update.message.reply_text(
        f"سلام {user.first_name}! به ربات NetBox خوش آمدید.\n"
        "برای مشاهده منو از دستور /menu استفاده کنید."
    )

async def menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """دستور /menu"""
    user = update.effective_user
    async with asyncpg.create_pool(**DB_CONFIG) as pool:
        # دریافت اطلاعات کاربر
        user_data = await pool.fetchrow('''
            SELECT balance FROM users WHERE user_id = $1
        ''', user.id)
        
        balance = user_data['balance'] if user_data else 0
    
    menu_text = (
        f"👋 سلام {user.first_name}!\n\n"
        f"💰 موجودی: {balance} تومان\n\n"
        "🔸 منوی اصلی:\n"
        "1️⃣ خرید پلن\n"
        "2️⃣ پنل‌های من\n"
        "3️⃣ تراکنش‌ها\n"
        "4️⃣ پشتیبانی\n"
        "5️⃣ تنظیمات\n\n"
        "برای انتخاب گزینه مورد نظر، شماره آن را ارسال کنید."
    )
    
    await update.message.reply_text(menu_text)

async def echo(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """پاسخ به پیام‌های عادی"""
    user = update.effective_user
    message_text = update.message.text
    
    async with asyncpg.create_pool(**DB_CONFIG) as pool:
        # ذخیره پیام در دیتابیس
        await pool.execute('''
            INSERT INTO messages (user_id, message_text)
            VALUES ($1, $2)
        ''', user.id, message_text)
        
        # آپدیت آخرین فعالیت کاربر
        await pool.execute('''
            UPDATE users
            SET last_activity = NOW()
            WHERE user_id = $1
        ''', user.id)
    
    # بررسی دستورات منو
    if message_text == "1":
        await update.message.reply_text("در حال آماده‌سازی لیست پلن‌ها...")
    elif message_text == "2":
        await update.message.reply_text("در حال دریافت لیست پنل‌های شما...")
    elif message_text == "3":
        await update.message.reply_text("در حال دریافت لیست تراکنش‌های شما...")
    elif message_text == "4":
        await update.message.reply_text("برای ارتباط با پشتیبانی، پیام خود را ارسال کنید.")
    elif message_text == "5":
        await update.message.reply_text("تنظیمات در حال آماده‌سازی است...")
    else:
        await update.message.reply_text("پیام شما دریافت شد!")

async def error(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """مدیریت خطاها"""
    logger.error(f"خطا در پردازش پیام: {context.error}")
    if update and update.effective_message:
        await update.effective_message.reply_text(
            "متاسفانه در پردازش پیام شما خطایی رخ داد. لطفا دوباره تلاش کنید."
        )

def main():
    """تابع اصلی"""
    # دریافت توکن از متغیرهای محیطی
    token = os.getenv('BOT_TOKEN')
    
    # ایجاد برنامه
    application = Application.builder().token(token).build()
    
    # اضافه کردن هندلرها
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("menu", menu))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, echo))
    
    # اضافه کردن هندلر خطا
    application.add_error_handler(error)
    
    # تنظیم وب‌هوک
    webhook_url = os.getenv('WEBHOOK_URL')
    webhook_port = int(os.getenv('WEBHOOK_PORT', '8443'))
    
    # شروع ربات
    application.run_webhook(
        listen='0.0.0.0',
        port=webhook_port,
        url_path='/webhook.php',
        webhook_url=webhook_url
    )

if __name__ == '__main__':
    main()
EOL

    cat > /opt/netbox/requirements.txt << 'EOL'
python-telegram-bot==13.12
python-dotenv==1.0.1
asyncpg==0.29.0
aiohttp==3.9.1
apscheduler==3.10.4
schedule==1.2.1
cryptography==41.0.7
EOL

    cat > /opt/netbox/config.php << 'EOL'
<?php
// تنظیمات دیتابیس
define('DB_HOST', 'localhost');
define('DB_NAME', 'netbox_db');
define('DB_USER', getenv('DB_USER'));
define('DB_PASS', getenv('DB_PASS'));

// تنظیمات ربات
define('BOT_TOKEN', getenv('BOT_TOKEN'));
define('ADMIN_ID', getenv('ADMIN_ID'));

// تنظیمات وب‌هوک
define('WEBHOOK_URL', getenv('WEBHOOK_URL'));
define('WEBHOOK_PORT', getenv('WEBHOOK_PORT'));

// تنظیمات عمومی
define('SITE_NAME', 'NetBox');
define('SITE_URL', WEBHOOK_URL);
define('ADMIN_EMAIL', 'admin@example.com');
define('SUPPORT_EMAIL', 'support@example.com');

// تنظیمات نوتیفیکیشن
define('NOTIFICATION_ENABLED', true);
define('TELEGRAM_NOTIFICATION', true);
define('EMAIL_NOTIFICATION', false);

// تنظیمات پشتیبان‌گیری
define('BACKUP_ENABLED', true);
define('BACKUP_PATH', '/opt/netbox/backups');
define('BACKUP_RETENTION', 7);

// تنظیمات پروتکل‌ها
$PROTOCOLS = [
    'vmess' => [
        'enabled' => true,
        'default_port' => 443,
        'default_alter_id' => 0,
        'default_network' => 'ws'
    ],
    'vless' => [
        'enabled' => true,
        'default_port' => 443,
        'default_network' => 'ws'
    ],
    'trojan' => [
        'enabled' => true,
        'default_port' => 443,
        'default_password' => ''
    ]
];

// تنظیمات شبکه
$NETWORKS = [
    'ws' => [
        'enabled' => true,
        'default_path' => '/ws',
        'default_host' => ''
    ],
    'tcp' => [
        'enabled' => true,
        'default_port' => 443
    ],
    'kcp' => [
        'enabled' => false,
        'default_port' => 443
    ]
];

// تنظیمات پنل‌ها
$PANELS = [
    'x-ui' => [
        'enabled' => true,
        'default_path' => '/xui',
        'default_username' => 'admin',
        'default_password' => 'admin'
    ],
    'marzban' => [
        'enabled' => true,
        'default_path' => '/marzban',
        'default_username' => 'admin',
        'default_password' => 'admin'
    ]
];
EOL

    cat > /opt/netbox/createDB.php << 'EOL'
<?php
require_once 'config.php';

try {
    // اتصال به PostgreSQL
    $pdo = new PDO(
        "pgsql:host=" . DB_HOST . ";dbname=postgres",
        DB_USER,
        DB_PASS
    );
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // بررسی وجود دیتابیس
    $result = $pdo->query("SELECT 1 FROM pg_database WHERE datname = '" . DB_NAME . "'");
    if ($result->rowCount() == 0) {
        // ایجاد دیتابیس
        $pdo->exec("CREATE DATABASE " . DB_NAME);
        echo "دیتابیس " . DB_NAME . " با موفقیت ایجاد شد.\n";
    }
    
    // اتصال به دیتابیس جدید
    $pdo = new PDO(
        "pgsql:host=" . DB_HOST . ";dbname=" . DB_NAME,
        DB_USER,
        DB_PASS
    );
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // ایجاد جداول
    $tables = [
        // جدول کاربران
        "CREATE TABLE IF NOT EXISTS users (
            user_id BIGINT PRIMARY KEY,
            username TEXT,
            first_name TEXT,
            last_name TEXT,
            phone TEXT,
            email TEXT,
            balance DECIMAL(10,2) DEFAULT 0,
            is_admin BOOLEAN DEFAULT FALSE,
            is_banned BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            last_purchase TIMESTAMP WITH TIME ZONE,
            total_purchases DECIMAL(10,2) DEFAULT 0,
            total_spent DECIMAL(10,2) DEFAULT 0
        )",
        
        // جدول پیام‌ها
        "CREATE TABLE IF NOT EXISTS messages (
            id SERIAL PRIMARY KEY,
            user_id BIGINT REFERENCES users(user_id),
            message_text TEXT,
            message_type TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )",
        
        // جدول تنظیمات
        "CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )",
        
        // جدول پنل‌ها
        "CREATE TABLE IF NOT EXISTS panels (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            url TEXT NOT NULL,
            username TEXT NOT NULL,
            password TEXT NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            last_check TIMESTAMP WITH TIME ZONE,
            status TEXT DEFAULT 'unknown'
        )",
        
        // جدول سرورها
        "CREATE TABLE IF NOT EXISTS servers (
            id SERIAL PRIMARY KEY,
            panel_id INTEGER REFERENCES panels(id),
            name TEXT NOT NULL,
            ip TEXT NOT NULL,
            port INTEGER NOT NULL,
            protocol TEXT NOT NULL,
            network TEXT NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            last_check TIMESTAMP WITH TIME ZONE,
            status TEXT DEFAULT 'unknown'
        )",
        
        // جدول پلن‌ها
        "CREATE TABLE IF NOT EXISTS plans (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            price DECIMAL(10,2) NOT NULL,
            duration INTEGER NOT NULL, -- در روز
            traffic_limit BIGINT NOT NULL, -- در مگابایت
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )",
        
        // جدول خریدها
        "CREATE TABLE IF NOT EXISTS purchases (
            id SERIAL PRIMARY KEY,
            user_id BIGINT REFERENCES users(user_id),
            plan_id INTEGER REFERENCES plans(id),
            server_id INTEGER REFERENCES servers(id),
            amount DECIMAL(10,2) NOT NULL,
            status TEXT NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            completed_at TIMESTAMP WITH TIME ZONE,
            expires_at TIMESTAMP WITH TIME ZONE,
            config_data JSONB
        )",
        
        // جدول تراکنش‌ها
        "CREATE TABLE IF NOT EXISTS transactions (
            id SERIAL PRIMARY KEY,
            user_id BIGINT REFERENCES users(user_id),
            amount DECIMAL(10,2) NOT NULL,
            type TEXT NOT NULL,
            status TEXT NOT NULL,
            description TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            completed_at TIMESTAMP WITH TIME ZONE,
            payment_data JSONB
        )",
        
        // جدول لاگ‌ها
        "CREATE TABLE IF NOT EXISTS logs (
            id SERIAL PRIMARY KEY,
            user_id BIGINT REFERENCES users(user_id),
            action TEXT NOT NULL,
            details TEXT,
            ip TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )",
        
        // جدول کوپن‌ها
        "CREATE TABLE IF NOT EXISTS coupons (
            id SERIAL PRIMARY KEY,
            code TEXT UNIQUE NOT NULL,
            discount_percent INTEGER NOT NULL,
            max_uses INTEGER,
            used_count INTEGER DEFAULT 0,
            expires_at TIMESTAMP WITH TIME ZONE,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )",
        
        // جدول استفاده از کوپن‌ها
        "CREATE TABLE IF NOT EXISTS coupon_uses (
            id SERIAL PRIMARY KEY,
            coupon_id INTEGER REFERENCES coupons(id),
            user_id BIGINT REFERENCES users(user_id),
            used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )",
        
        // جدول اعلان‌ها
        "CREATE TABLE IF NOT EXISTS notifications (
            id SERIAL PRIMARY KEY,
            user_id BIGINT REFERENCES users(user_id),
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            type TEXT NOT NULL,
            is_read BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )",
        
        // جدول پشتیبان‌ها
        "CREATE TABLE IF NOT EXISTS backups (
            id SERIAL PRIMARY KEY,
            filename TEXT NOT NULL,
            size BIGINT NOT NULL,
            type TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            expires_at TIMESTAMP WITH TIME ZONE
        )"
    ];
    
    // اجرای کوئری‌های ساخت جداول
    foreach ($tables as $sql) {
        $pdo->exec($sql);
    }
    
    echo "جداول با موفقیت ایجاد شدند.\n";
    
    // ایجاد کاربر ادمین پیش‌فرض
    $admin_id = ADMIN_ID;
    $stmt = $pdo->prepare("INSERT INTO users (user_id, username, is_admin) VALUES (?, 'admin', TRUE) ON CONFLICT (user_id) DO UPDATE SET is_admin = TRUE");
    $stmt->execute([$admin_id]);
    
    echo "کاربر ادمین با موفقیت ایجاد شد.\n";
    
    // تنظیمات پیش‌فرض
    $settings = [
        ['site_name', 'NetBox Bot'],
        ['site_url', SITE_URL],
        ['support_username', ''],
        ['channel_username', ''],
        ['group_username', ''],
        ['minimum_purchase', '10000'],
        ['maximum_purchase', '1000000'],
        ['commission_rate', '0.1'],
        ['backup_enabled', 'true'],
        ['backup_path', BACKUP_PATH],
        ['backup_retention_days', '7'],
        ['backup_time', '00:00'],
        ['smtp_host', ''],
        ['smtp_port', '587'],
        ['smtp_username', ''],
        ['smtp_from_email', ''],
        ['smtp_from_name', SITE_NAME],
        ['zarinpal_merchant', ''],
        ['nextpay_api_key', ''],
        ['nowpayments_api_key', '']
    ];
    
    $stmt = $pdo->prepare("INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value");
    foreach ($settings as $setting) {
        $stmt->execute($setting);
    }
    
    echo "تنظیمات پیش‌فرض با موفقیت ایجاد شدند.\n";
    
} catch (PDOException $e) {
    echo "خطا: " . $e->getMessage() . "\n";
    exit(1);
}
EOL

    # تنظیم متغیرهای محیطی
    cat > /opt/netbox/.env << EOL
BOT_TOKEN=${BOT_TOKEN}
ADMIN_ID=${ADMIN_ID}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
WEBHOOK_URL=https://${DOMAIN}
WEBHOOK_PORT=${WEBHOOK_PORT}
EOL
    
    # ایجاد محیط مجازی
    echo -e "${YELLOW}ایجاد محیط مجازی پایتون...${NC}"
    python3 -m venv /opt/netbox/venv
    source /opt/netbox/venv/bin/activate
    
    # نصب پکیج‌های پایتون
    echo -e "${YELLOW}نصب پکیج‌های پایتون...${NC}"
    pip install --upgrade pip
    pip install -r /opt/netbox/requirements.txt
    
    # نصب پکیج‌های PHP
    echo -e "${YELLOW}نصب پکیج‌های PHP...${NC}"
    apt-get install -y php-pgsql php-curl php-gd php-mbstring php-xml php-zip php-fpm
    
    # ساخت دیتابیس
    echo -e "${YELLOW}ساخت دیتابیس...${NC}"
    cd /opt/netbox
    php createDB.php
    
    # تنظیم Nginx
    rm -f /etc/nginx/sites-enabled/netbox
    rm -f /etc/nginx/sites-enabled/default
    
    cat > /etc/nginx/sites-available/netbox << EOL
server {
    listen 80;
    server_name ${DOMAIN};
    
    root /opt/netbox;
    index index.php index.html;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location /webhook.php {
        proxy_pass http://localhost:${WEBHOOK_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};
    
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    
    root /opt/netbox;
    index index.php index.html;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location /webhook.php {
        proxy_pass http://localhost:${WEBHOOK_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOL
    
    ln -s /etc/nginx/sites-available/netbox /etc/nginx/sites-enabled/
    
    # تنظیم مجوزها
    chown -R www-data:www-data /opt/netbox
    chmod -R 755 /opt/netbox
    chmod -R 777 /opt/netbox/assets
    chmod -R 777 /opt/netbox/backups
    
    # راه‌اندازی مجدد سرویس‌ها
    systemctl restart nginx
    systemctl restart php-fpm
    
    # تنظیم سرویس
    cat > /etc/systemd/system/netbox.service << EOL
[Unit]
Description=NetBox Telegram Bot
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/netbox
Environment=PATH=/opt/netbox/venv/bin
ExecStart=/opt/netbox/venv/bin/python3 bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL
    
    # فعال‌سازی و شروع سرویس
    systemctl daemon-reload
    systemctl enable netbox
    systemctl start netbox
    
    # ارسال پیام به ادمین
    send_telegram_message "✅ نصب ربات با موفقیت انجام شد.\n\n🔗 آدرس وب‌هوک:\n🔸 HTTP: http://${DOMAIN}/webhook.php\n🔸 HTTPS: https://${DOMAIN}/webhook.php\n\n📝 اطلاعات دیتابیس:\n🔸 نام کاربری: ${DB_USER}\n🔸 رمز عبور: ${DB_PASS}\n🔸 نام دیتابیس: netbox_db"
    
    echo -e "${GREEN}نصب ربات با موفقیت انجام شد.${NC}"
    echo -e "${YELLOW}آدرس وب‌هوک:${NC}"
    echo -e "${YELLOW}HTTP: http://${DOMAIN}/webhook.php${NC}"
    echo -e "${YELLOW}HTTPS: https://${DOMAIN}/webhook.php${NC}"
}

# تابع آپدیت
update() {
    echo -e "${YELLOW}شروع آپدیت ربات NetBox...${NC}"
    
    # فعال‌سازی محیط مجازی
    source /opt/netbox/venv/bin/activate
    
    # آپدیت پکیج‌های پایتون
    echo -e "${YELLOW}آپدیت پکیج‌های پایتون...${NC}"
    pip install --upgrade -r /opt/netbox/requirements.txt
    
    # راه‌اندازی مجدد سرویس
    systemctl restart netbox
    
    # ارسال پیام به ادمین
    send_telegram_message "✅ آپدیت ربات با موفقیت انجام شد."
    
    echo -e "${GREEN}آپدیت ربات با موفقیت انجام شد.${NC}"
}

# تابع حذف
uninstall() {
    echo -e "${YELLOW}شروع حذف ربات NetBox...${NC}"
    
    # توقف و حذف سرویس
    systemctl stop netbox
    systemctl disable netbox
    rm -f /etc/systemd/system/netbox.service
    
    # حذف تنظیمات Nginx
    rm -f /etc/nginx/sites-enabled/netbox
    rm -f /etc/nginx/sites-available/netbox
    
    # حذف فایل‌ها
    rm -rf /opt/netbox
    
    # راه‌اندازی مجدد Nginx
    systemctl restart nginx
    
    # ارسال پیام به ادمین
    send_telegram_message "✅ حذف ربات با موفقیت انجام شد."
    
    echo -e "${GREEN}حذف ربات با موفقیت انجام شد.${NC}"
}

# تابع تنظیم وب‌هوک
setup_webhook() {
    echo -e "${YELLOW}شروع تنظیم وب‌هوک...${NC}"
    
    # دریافت اطلاعات
    read -p "لطفا توکن ربات را وارد کنید: " BOT_TOKEN
    read -p "لطفا شناسه ادمین را وارد کنید: " ADMIN_ID
    read -p "لطفا نام کاربری دیتابیس را وارد کنید: " DB_USER
    read -p "لطفا رمز عبور دیتابیس را وارد کنید: " DB_PASS
    read -p "لطفا دامنه یا IP سرور را وارد کنید: " DOMAIN
    read -p "لطفا پورت وب‌هوک را وارد کنید (پیش‌فرض: 8443): " WEBHOOK_PORT
    WEBHOOK_PORT=${WEBHOOK_PORT:-8443}
    
    # تنظیم متغیرهای محیطی
    cat > /opt/netbox/.env << EOL
BOT_TOKEN=${BOT_TOKEN}
ADMIN_ID=${ADMIN_ID}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
WEBHOOK_URL=https://${DOMAIN}
WEBHOOK_PORT=${WEBHOOK_PORT}
EOL
    
    # راه‌اندازی مجدد سرویس
    systemctl restart netbox
    
    # ارسال پیام به ادمین
    send_telegram_message "✅ تنظیم وب‌هوک با موفقیت انجام شد.\n\n🔗 آدرس وب‌هوک:\n🔸 HTTP: http://${DOMAIN}/webhook.php\n🔸 HTTPS: https://${DOMAIN}/webhook.php"
    
    echo -e "${GREEN}تنظیم وب‌هوک با موفقیت انجام شد.${NC}"
    echo -e "${YELLOW}آدرس وب‌هوک:${NC}"
    echo -e "${YELLOW}HTTP: http://${DOMAIN}/webhook.php${NC}"
    echo -e "${YELLOW}HTTPS: https://${DOMAIN}/webhook.php${NC}"
}

# منوی اصلی
while true; do
    echo -e "\n${YELLOW}منوی مدیریت ربات NetBox:${NC}"
    echo "1) نصب ربات"
    echo "2) آپدیت ربات"
    echo "3) حذف ربات"
    echo "4) تنظیم وب‌هوک"
    echo "5) خروج"
    
    read -p "لطفا یک گزینه را انتخاب کنید: " choice
    
    case $choice in
        1) install ;;
        2) update ;;
        3) uninstall ;;
        4) setup_webhook ;;
        5) exit 0 ;;
        *) echo -e "${RED}گزینه نامعتبر است.${NC}" ;;
    esac
done 