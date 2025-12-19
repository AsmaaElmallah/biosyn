-- ============================================
-- ADD QUICK SESSION COLUMN TO REPORTS TABLE
-- ============================================
-- 
-- هذا الملف يضيف column جديد `is_quick_session` في reports table
-- لتمييز الـ Quick Coaching Sessions (اللي تمت بدون plan)
--
-- الخطوات:
-- 1. افتح Supabase Dashboard
-- 2. اذهب إلى SQL Editor
-- 3. انسخ محتوى هذا الملف
-- 4. الصقه في SQL Editor
-- 5. اضغط Run
-- ============================================

-- إضافة column is_quick_session
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS is_quick_session BOOLEAN DEFAULT FALSE;

-- تحديث الـ column description
COMMENT ON COLUMN reports.is_quick_session IS 'True if session was started without a scheduled plan for the date';

