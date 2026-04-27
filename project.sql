-- 1. إنشاء قاعدة بيانات المشروع
CREATE DATABASE IF NOT EXISTS FitnessApp;
USE FitnessApp;

-- 2. جدول المعلومات الأساسية للمستخدم
CREATE TABLE user_info (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE, -- الإيميل (لا يتكرر ولا يترك فارغاً)
    password VARCHAR(255) NOT NULL,    -- كلمة المرور
    birth_date DATE, -- السن يُحسب من تاريخ الميلاد ليكون أدق
    gender ENUM('Male', 'Female'), -- تحديد الجنس
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. جدول القياسات المتغيرة (هذا هو الأهم لمشروعك)
CREATE TABLE health_metrics (
    metric_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT, -- ربط القياس بالمستخدم
    weight FLOAT, -- الوزن
    height FLOAT, -- الطول (قد يتغير في السن الصغير)
    heart_rate INT, -- عدد ضربات القلب
    oxygen_level INT, -- نسبة الأكسجين في الدم
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- وقت وتاريخ أخذ القياس
    
    -- ربط الجدولين ببعض (Foreign Key)
    FOREIGN KEY (user_id) REFERENCES user_info(user_id) ON DELETE CASCADE
);