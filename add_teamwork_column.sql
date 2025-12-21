-- ============================================
-- MIGRATION: Add Teamwork Column to Reports
-- ============================================
-- 
-- هذا الملف يحتوي على Migration لإضافة حقل "Teamwork and Cooperation"
-- إلى جدول reports في Supabase
--
-- الخطوات:
-- 1. افتح Supabase Dashboard
-- 2. اذهب إلى SQL Editor
-- 3. انسخ محتوى هذا الملف
-- 4. الصقه في SQL Editor
-- 5. اضغط Run
-- ============================================

-- إضافة حقل teamwork_and_cooperation إلى جدول reports
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS teamwork_and_cooperation VARCHAR(10) 
CHECK (teamwork_and_cooperation IN ('High', 'Medium', 'Low'));

-- ============================================
-- VERIFICATION
-- ============================================
-- تحقق من إضافة الحقل:
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'reports' AND column_name = 'teamwork_and_cooperation';

-- ============================================
-- END OF MIGRATION
-- ============================================

