-- ============================================
-- MIGRATION: Add New Roles and Fields
-- ============================================
-- 
-- هذا الملف يحتوي على Migration لتحديث Database Schema
-- لإضافة Roles جديدة (ft, pm, msl) و Fields جديدة للـ Reports
--
-- الخطوات:
-- 1. افتح Supabase Dashboard
-- 2. اذهب إلى SQL Editor
-- 3. انسخ محتوى هذا الملف
-- 4. الصقه في SQL Editor
-- 5. اضغط Run
-- ============================================

-- ============================================
-- 1. UPDATE USERS TABLE - Add New Roles
-- ============================================
-- تحديث CHECK constraint للـ role لإضافة ft, pm, msl
ALTER TABLE users 
DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE users 
ADD CONSTRAINT users_role_check 
CHECK (role IN ('dm', 'ft', 'gm', 'pm', 'msl', 'mr'));

-- إضافة Profile Picture URL column
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS profile_picture_url TEXT;

-- ============================================
-- 2. UPDATE REPORTS TABLE - Add New Fields
-- ============================================
-- إضافة Coach Role field للتمييز بين أنواع الـ coaching
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS coach_role VARCHAR(10) 
CHECK (coach_role IN ('dm', 'ft', 'pm', 'msl'));

-- Brick Information Fields (لجميع الـ Forms)
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS brick_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS brick_location_lat DECIMAL(10, 8),
ADD COLUMN IF NOT EXISTS brick_location_lng DECIMAL(11, 8),
ADD COLUMN IF NOT EXISTS visit_count INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS doctors_visited TEXT; -- Comma-separated list

-- PM/MSL Specific Fields
ALTER TABLE reports 
ADD COLUMN IF NOT EXISTS area_brick_name VARCHAR(255), -- For PM/MSL: "Area & Brick Name"
ADD COLUMN IF NOT EXISTS type_of_visit VARCHAR(20) CHECK (type_of_visit IN ('DM', 'Single', 'Double', 'Triple')),
ADD COLUMN IF NOT EXISTS visited_accounts_names TEXT, -- For PM/MSL
ADD COLUMN IF NOT EXISTS general_feedback TEXT, -- For PM/MSL: "General Feedback and Special Insights"
ADD COLUMN IF NOT EXISTS customer_awareness VARCHAR(10) CHECK (customer_awareness IN ('High', 'Medium', 'Low')),
ADD COLUMN IF NOT EXISTS medical_product_knowledge_dm VARCHAR(10) CHECK (medical_product_knowledge_dm IN ('High', 'Medium', 'Low')),
ADD COLUMN IF NOT EXISTS dm_feedback_comments TEXT, -- For PM/MSL: "DM Feedback Comments and Insights"
ADD COLUMN IF NOT EXISTS patient_centric_approach VARCHAR(10), -- 1-6 scale
ADD COLUMN IF NOT EXISTS medical_product_knowledge_mr VARCHAR(10), -- 1-6 scale
ADD COLUMN IF NOT EXISTS feature_benefits VARCHAR(10), -- 1-6 scale
ADD COLUMN IF NOT EXISTS closing_commitment VARCHAR(10), -- 1-6 scale
ADD COLUMN IF NOT EXISTS mr_feedback_comments TEXT; -- For PM/MSL: "MR Feedback Comments and Insights"

-- ============================================
-- 3. UPDATE RLS POLICIES - Add Support for New Roles
-- ============================================
-- تحديث Policies لدعم FT, PM, MSL (نفس صلاحيات DM)
-- Policy: FT/PM/MSL can read own reports
DROP POLICY IF EXISTS "FT can read own reports" ON reports;
CREATE POLICY "FT can read own reports"
    ON reports FOR SELECT
    USING (
        (coach_role = 'ft' AND dm_id::text = auth.uid()::text)
        OR EXISTS (
            SELECT 1 FROM users
            WHERE id::text = auth.uid()::text
            AND role = 'gm'
        )
    );

DROP POLICY IF EXISTS "PM can read own reports" ON reports;
CREATE POLICY "PM can read own reports"
    ON reports FOR SELECT
    USING (
        (coach_role = 'pm' AND dm_id::text = auth.uid()::text)
        OR EXISTS (
            SELECT 1 FROM users
            WHERE id::text = auth.uid()::text
            AND role = 'gm'
        )
    );

DROP POLICY IF EXISTS "MSL can read own reports" ON reports;
CREATE POLICY "MSL can read own reports"
    ON reports FOR SELECT
    USING (
        (coach_role = 'msl' AND dm_id::text = auth.uid()::text)
        OR EXISTS (
            SELECT 1 FROM users
            WHERE id::text = auth.uid()::text
            AND role = 'gm'
        )
    );

-- Policy: FT/PM/MSL can insert own reports
DROP POLICY IF EXISTS "FT can insert own reports" ON reports;
CREATE POLICY "FT can insert own reports"
    ON reports FOR INSERT
    WITH CHECK (
        coach_role = 'ft' AND dm_id::text = auth.uid()::text
    );

DROP POLICY IF EXISTS "PM can insert own reports" ON reports;
CREATE POLICY "PM can insert own reports"
    ON reports FOR INSERT
    WITH CHECK (
        coach_role = 'pm' AND dm_id::text = auth.uid()::text
    );

DROP POLICY IF EXISTS "MSL can insert own reports" ON reports;
CREATE POLICY "MSL can insert own reports"
    ON reports FOR INSERT
    WITH CHECK (
        coach_role = 'msl' AND dm_id::text = auth.uid()::text
    );

-- ============================================
-- 4. CREATE STORAGE BUCKET FOR PROFILE PICTURES
-- ============================================
-- إنشاء Storage Bucket للصور
INSERT INTO storage.buckets (id, name, public) 
VALUES ('user-profiles', 'user-profiles', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 5. STORAGE POLICIES FOR PROFILE PICTURES
-- ============================================
-- Policy: GM can upload/read/update/delete any profile picture (for user management)
DROP POLICY IF EXISTS "GM can manage all profile pictures" ON storage.objects;
CREATE POLICY "GM can manage all profile pictures"
    ON storage.objects FOR ALL
    USING (
        bucket_id = 'user-profiles'
        AND EXISTS (
            SELECT 1 FROM users
            WHERE id::text = auth.uid()::text
            AND role = 'gm'
        )
    )
    WITH CHECK (
        bucket_id = 'user-profiles'
        AND EXISTS (
            SELECT 1 FROM users
            WHERE id::text = auth.uid()::text
            AND role = 'gm'
        )
    );

-- Policy: Anyone can read profile pictures (public bucket)
DROP POLICY IF EXISTS "Anyone can read profile pictures" ON storage.objects;
CREATE POLICY "Anyone can read profile pictures"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'user-profiles');

-- Policy: Authenticated users can upload profile pictures
-- Note: The app will handle user-specific file naming (profile_userId_timestamp.jpg)
DROP POLICY IF EXISTS "Authenticated users can upload profile pictures" ON storage.objects;
CREATE POLICY "Authenticated users can upload profile pictures"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'user-profiles'
        AND auth.role() = 'authenticated'
    );

-- Policy: Authenticated users can update profile pictures
DROP POLICY IF EXISTS "Authenticated users can update profile pictures" ON storage.objects;
CREATE POLICY "Authenticated users can update profile pictures"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'user-profiles'
        AND auth.role() = 'authenticated'
    )
    WITH CHECK (
        bucket_id = 'user-profiles'
        AND auth.role() = 'authenticated'
    );

-- Policy: Authenticated users can delete profile pictures
DROP POLICY IF EXISTS "Authenticated users can delete profile pictures" ON storage.objects;
CREATE POLICY "Authenticated users can delete profile pictures"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'user-profiles'
        AND auth.role() = 'authenticated'
    );

-- ============================================
-- 6. VERIFICATION
-- ============================================
-- تحقق من التحديثات:
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'users' AND column_name = 'profile_picture_url';

-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'reports' 
-- AND column_name IN ('coach_role', 'brick_name', 'brick_location_lat', 'visit_count');

-- ============================================
-- END OF MIGRATION
-- ============================================

