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

// تنظیمات درگاه‌های پرداخت
define('ZARINPAL_MERCHANT', '');
define('NEXTPAY_API_KEY', '');
define('NOWPAYMENTS_API_KEY', '');

// تنظیمات پنل‌ها
define('PANEL_URL', '');
define('PANEL_USERNAME', '');
define('PANEL_PASSWORD', '');
define('PANEL_TYPE', 'x-ui'); // x-ui, marzban, etc.

// تنظیمات امنیتی
define('API_KEY', ''); // کلید API برای دسترسی به وب‌سرویس
define('ALLOWED_IPS', []); // لیست IP های مجاز

// تنظیمات عمومی
define('SITE_URL', '');
define('SITE_NAME', 'NetBox Bot');
define('SUPPORT_USERNAME', '');
define('CHANNEL_USERNAME', '');
define('GROUP_USERNAME', '');

// تنظیمات اعلان‌ها
define('NOTIFY_NEW_USER', true);
define('NOTIFY_NEW_PURCHASE', true);
define('NOTIFY_LOW_BALANCE', true);
define('NOTIFY_EXPIRING_SERVICES', true);

// تنظیمات پشتیبانی
define('SUPPORT_EMAIL', '');
define('SUPPORT_PHONE', '');
define('SUPPORT_WORK_HOURS', '9:00-18:00');

// تنظیمات مالی
define('MINIMUM_PURCHASE', 10000);
define('MAXIMUM_PURCHASE', 1000000);
define('COMMISSION_RATE', 0.1); // 10% commission

// تنظیمات امنیتی اضافی
define('MAX_LOGIN_ATTEMPTS', 3);
define('LOGIN_TIMEOUT', 300); // 5 minutes
define('SESSION_LIFETIME', 3600); // 1 hour

// تنظیمات لاگینگ
define('LOG_PATH', '/var/log/netbox/');
define('LOG_LEVEL', 'INFO'); // DEBUG, INFO, WARNING, ERROR

// تنظیمات کش
define('CACHE_ENABLED', true);
define('CACHE_LIFETIME', 300); // 5 minutes
define('CACHE_PATH', '/tmp/netbox/');

// تنظیمات ایمیل
define('SMTP_HOST', '');
define('SMTP_PORT', 587);
define('SMTP_USERNAME', '');
define('SMTP_PASSWORD', '');
define('SMTP_FROM_EMAIL', '');
define('SMTP_FROM_NAME', SITE_NAME);

// تنظیمات امنیتی SSL
define('SSL_ENABLED', true);
define('SSL_CERT_PATH', '/etc/letsencrypt/live/');
define('SSL_KEY_PATH', '/etc/letsencrypt/live/');

// تنظیمات محدودیت‌ها
define('MAX_CONNECTIONS', 100);
define('MAX_REQUESTS_PER_MINUTE', 60);
define('MAX_FILE_SIZE', 5242880); // 5MB

// تنظیمات زبان
define('DEFAULT_LANGUAGE', 'fa');
define('AVAILABLE_LANGUAGES', ['fa', 'en']);

// تنظیمات منطقه زمانی
define('TIMEZONE', 'Asia/Tehran');
date_default_timezone_set(TIMEZONE);

// تنظیمات امنیتی اضافی
define('PASSWORD_MIN_LENGTH', 8);
define('PASSWORD_REQUIRE_SPECIAL', true);
define('PASSWORD_REQUIRE_NUMBERS', true);
define('PASSWORD_REQUIRE_UPPERCASE', true);

// تنظیمات پشتیبان‌گیری
define('BACKUP_ENABLED', true);
define('BACKUP_PATH', '/var/backups/netbox/');
define('BACKUP_RETENTION_DAYS', 7);
define('BACKUP_TIME', '00:00'); // هر روز در ساعت 00:00

// تنظیمات اعلان‌های تلگرام
define('TELEGRAM_NOTIFICATIONS', true);
define('TELEGRAM_ERROR_NOTIFICATIONS', true);
define('TELEGRAM_DEBUG_NOTIFICATIONS', false);

// تنظیمات API تلگرام
define('TELEGRAM_API_URL', 'https://api.telegram.org/bot' . BOT_TOKEN);
define('TELEGRAM_WEBHOOK_URL', WEBHOOK_URL);
define('TELEGRAM_WEBHOOK_PORT', WEBHOOK_PORT);

// تنظیمات امنیتی API
define('API_RATE_LIMIT', 100); // تعداد درخواست در دقیقه
define('API_RATE_WINDOW', 60); // پنجره زمانی (ثانیه)
define('API_KEY_REQUIRED', true);

// تنظیمات پنل‌های مختلف
$PANEL_CONFIGS = [
    'x-ui' => [
        'url' => PANEL_URL,
        'username' => PANEL_USERNAME,
        'password' => PANEL_PASSWORD,
        'api_path' => '/api/inbounds',
        'version' => '1.0.0'
    ],
    'marzban' => [
        'url' => PANEL_URL,
        'username' => PANEL_USERNAME,
        'password' => PANEL_PASSWORD,
        'api_path' => '/api/users',
        'version' => '1.0.0'
    ]
];

// تنظیمات پروتکل‌ها
$PROTOCOLS = [
    'vmess' => [
        'enabled' => true,
        'default_port' => 443,
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
        'default_network' => 'tcp'
    ]
];

// تنظیمات شبکه‌ها
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
    'grpc' => [
        'enabled' => true,
        'default_path' => '/grpc'
    ]
];

// تنظیمات امنیتی TLS
$TLS_CONFIG = [
    'enabled' => true,
    'cert_path' => SSL_CERT_PATH,
    'key_path' => SSL_KEY_PATH,
    'min_version' => 'TLSv1.2',
    'cipher_suites' => [
        'ECDHE-ECDSA-AES128-GCM-SHA256',
        'ECDHE-RSA-AES128-GCM-SHA256',
        'ECDHE-ECDSA-AES256-GCM-SHA384',
        'ECDHE-RSA-AES256-GCM-SHA384'
    ]
];

// تنظیمات امنیتی اضافی
$SECURITY_CONFIG = [
    'allowed_ips' => ALLOWED_IPS,
    'max_login_attempts' => MAX_LOGIN_ATTEMPTS,
    'login_timeout' => LOGIN_TIMEOUT,
    'session_lifetime' => SESSION_LIFETIME,
    'password_min_length' => PASSWORD_MIN_LENGTH,
    'password_require_special' => PASSWORD_REQUIRE_SPECIAL,
    'password_require_numbers' => PASSWORD_REQUIRE_NUMBERS,
    'password_require_uppercase' => PASSWORD_REQUIRE_UPPERCASE
];

// تنظیمات لاگینگ
$LOGGING_CONFIG = [
    'path' => LOG_PATH,
    'level' => LOG_LEVEL,
    'max_size' => 5242880, // 5MB
    'max_files' => 5,
    'format' => '[%datetime%] %channel%.%level_name%: %message% %context% %extra%'
];

// تنظیمات کش
$CACHE_CONFIG = [
    'enabled' => CACHE_ENABLED,
    'lifetime' => CACHE_LIFETIME,
    'path' => CACHE_PATH,
    'prefix' => 'netbox_'
];

// تنظیمات ایمیل
$SMTP_CONFIG = [
    'host' => SMTP_HOST,
    'port' => SMTP_PORT,
    'username' => SMTP_USERNAME,
    'password' => SMTP_PASSWORD,
    'from_email' => SMTP_FROM_EMAIL,
    'from_name' => SMTP_FROM_NAME,
    'encryption' => 'tls'
];

// تنظیمات پشتیبان‌گیری
$BACKUP_CONFIG = [
    'enabled' => BACKUP_ENABLED,
    'path' => BACKUP_PATH,
    'retention_days' => BACKUP_RETENTION_DAYS,
    'time' => BACKUP_TIME,
    'compress' => true,
    'encrypt' => true
];

// تنظیمات اعلان‌های تلگرام
$TELEGRAM_CONFIG = [
    'notifications' => TELEGRAM_NOTIFICATIONS,
    'error_notifications' => TELEGRAM_ERROR_NOTIFICATIONS,
    'debug_notifications' => TELEGRAM_DEBUG_NOTIFICATIONS,
    'api_url' => TELEGRAM_API_URL,
    'webhook_url' => TELEGRAM_WEBHOOK_URL,
    'webhook_port' => TELEGRAM_WEBHOOK_PORT
];

// تنظیمات API
$API_CONFIG = [
    'rate_limit' => API_RATE_LIMIT,
    'rate_window' => API_RATE_WINDOW,
    'key_required' => API_KEY_REQUIRED,
    'key' => API_KEY,
    'allowed_methods' => ['GET', 'POST', 'PUT', 'DELETE'],
    'allowed_headers' => ['Content-Type', 'Authorization']
];

// تنظیمات عمومی
$GENERAL_CONFIG = [
    'site_url' => SITE_URL,
    'site_name' => SITE_NAME,
    'support_username' => SUPPORT_USERNAME,
    'channel_username' => CHANNEL_USERNAME,
    'group_username' => GROUP_USERNAME,
    'default_language' => DEFAULT_LANGUAGE,
    'available_languages' => AVAILABLE_LANGUAGES,
    'timezone' => TIMEZONE,
    'minimum_purchase' => MINIMUM_PURCHASE,
    'maximum_purchase' => MAXIMUM_PURCHASE,
    'commission_rate' => COMMISSION_RATE
];

// تنظیمات اعلان‌ها
$NOTIFICATION_CONFIG = [
    'new_user' => NOTIFY_NEW_USER,
    'new_purchase' => NOTIFY_NEW_PURCHASE,
    'low_balance' => NOTIFY_LOW_BALANCE,
    'expiring_services' => NOTIFY_EXPIRING_SERVICES
];

// تنظیمات پشتیبانی
$SUPPORT_CONFIG = [
    'email' => SUPPORT_EMAIL,
    'phone' => SUPPORT_PHONE,
    'work_hours' => SUPPORT_WORK_HOURS,
    'response_time' => '24h'
];

// تنظیمات محدودیت‌ها
$LIMIT_CONFIG = [
    'max_connections' => MAX_CONNECTIONS,
    'max_requests_per_minute' => MAX_REQUESTS_PER_MINUTE,
    'max_file_size' => MAX_FILE_SIZE
]; 