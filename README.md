# NextCloudInstaller
اسکریپت نصب NextCloud
# 🌩️ Nextcloud Auto-Installer Script

<div align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/a/a3/NEXTcloud.svg" width="200" />
  <h2>نصب خودکار Nextcloud با MariaDB, Redis, Nginx و PHP</h2>
  <p>اسکریپت Bash برای نصب سریع و امن Nextcloud روی سرورهای Ubuntu/Debian</p>
</div>

---

## 🔧 قابلیت‌های کلیدی
- ✅ نصب خودکار تمام وابستگی‌ها (PHP, Nginx, MariaDB, Redis)
- 🔐 رمزهای تصادفی امن برای پایگاه داده و کاربر ادمین
- ⚙️ پیکربندی اتوماتیک Nginx با بهینه‌سازی‌های عملکرد
- 🧠 استفاده از Redis برای کش سشن‌های PHP
- 🔄 مدیریت نصب‌های قبلی (حذف/حفاظت از داده‌ها)
- 📦 سازگار با آخرین نسخه Nextcloud (دانلود خودکار از سرورهای رسمی)

## 🛠 ابزارهای مورد استفاده
- **Bash** - زبان اصلی اسکریپت
- **MariaDB** - سیستم مدیریت پایگاه داده
- **Nginx** - سرور وب معکوس
- **PHP 8+** - زبان برنامه‌نویسی سمت سرور
- **Redis** - سیستم کش پیشرفته
- **Let's Encrypt** - برای راه‌اندازی HTTPS (قابل اضافه کردن در آینده)

## 🚀 نحوه نصب
**اخطار:** این اسکریپت برای سیستم‌های **Ubuntu 20.04+/Debian 10+** طراحی شده است

```bash
# دانلود و اجرای مستقیم اسکریپت از گیت‌هاب
curl -s https://raw.githubusercontent.com/RTDeveloperman/NextCloudInstaller/refs/heads/main/NextCloud_Installer.sh | sudo bash
```


📌 نکات مهم

💾 تمام داده‌ها در /var/www/nextcloud ذخیره می‌شوند

🔐 پس از نصب، فوراً رمزهای امن را در تنظیمات تغییر دهید

🔄 برای نصب مجدد، ابتدا دایرکتوری /var/www/nextcloud را پاک کنید

📦 این اسکریپت به صورت پیش‌فرض از HTTP استفاده می‌کند (برای HTTPS باید SSL را پیکربندی کنید)
