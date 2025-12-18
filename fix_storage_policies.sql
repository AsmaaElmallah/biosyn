-- ============================================
-- FIX: Storage Bucket and Policies for Profile Pictures
-- ============================================
-- هذا الملف يحل مشكلة رفع الصور
-- قم بتشغيله في Supabase SQL Editor
-- ============================================

-- 1. إنشاء Storage Bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('user-profiles', 'user-profiles', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. حذف Policies القديمة (إن وجدت)
DROP POLICY IF EXISTS "GM can manage all profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can read profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete profile pictures" ON storage.objects;

-- 3. إنشاء Policies جديدة

-- Policy: GM can upload/read/update/delete any profile picture
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
CREATE POLICY "Anyone can read profile pictures"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'user-profiles');

-- Policy: Authenticated users can upload profile pictures
CREATE POLICY "Authenticated users can upload profile pictures"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'user-profiles'
        AND auth.role() = 'authenticated'
    );

-- Policy: Authenticated users can update profile pictures
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
CREATE POLICY "Authenticated users can delete profile pictures"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'user-profiles'
        AND auth.role() = 'authenticated'
    );

-- ============================================
-- التحقق من النتيجة:
-- ============================================
-- 1. تحقق من وجود Bucket:
-- SELECT * FROM storage.buckets WHERE id = 'user-profiles';

-- 2. تحقق من وجود Policies:
-- SELECT * FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage';

-- ============================================
-- END
-- ============================================

