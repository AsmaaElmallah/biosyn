-- ============================================
-- ADD PHONE COLUMN TO USERS TABLE
-- ============================================
-- هذا الملف يضيف حقل phone إلى جدول users
--
-- الخطوات:
-- 1. افتح Supabase Dashboard
-- 2. اذهب إلى SQL Editor
-- 3. انسخ محتوى هذا الملف
-- 4. الصقه في SQL Editor
-- 5. اضغط Run
-- ============================================

-- إضافة Phone column إلى جدول users
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS phone VARCHAR(20);

-- التحقق من إضافة الحقل
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'phone';

-- ============================================
-- END
-- ============================================

