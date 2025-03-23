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
        ['support_username', SUPPORT_USERNAME],
        ['channel_username', CHANNEL_USERNAME],
        ['group_username', GROUP_USERNAME],
        ['minimum_purchase', MINIMUM_PURCHASE],
        ['maximum_purchase', MAXIMUM_PURCHASE],
        ['commission_rate', COMMISSION_RATE],
        ['backup_enabled', BACKUP_ENABLED ? 'true' : 'false'],
        ['backup_path', BACKUP_PATH],
        ['backup_retention_days', BACKUP_RETENTION_DAYS],
        ['backup_time', BACKUP_TIME],
        ['smtp_host', SMTP_HOST],
        ['smtp_port', SMTP_PORT],
        ['smtp_username', SMTP_USERNAME],
        ['smtp_from_email', SMTP_FROM_EMAIL],
        ['smtp_from_name', SMTP_FROM_NAME],
        ['zarinpal_merchant', ZARINPAL_MERCHANT],
        ['nextpay_api_key', NEXTPAY_API_KEY],
        ['nowpayments_api_key', NOWPAYMENTS_API_KEY]
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