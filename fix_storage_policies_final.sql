-- ============================================
-- FIX: Storage Bucket and Policies for Profile Pictures
-- ============================================
-- هذا الملف يحل مشكلة رفع الصور بشكل نهائي
-- قم بتشغيله في Supabase SQL Editor
-- ============================================

-- 1. إنشاء Storage Bucket (إذا لم يكن موجوداً)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) 
VALUES (
    'user-profiles', 
    'user-profiles', 
    true,
    5242880, -- 5MB limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET 
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

-- 2. حذف جميع Policies القديمة (إن وجدت)
DROP POLICY IF EXISTS "GM can manage all profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can read profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete profile pictures" ON storage.objects;
DROP POLICY IF EXISTS "Public read access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload access" ON storage.objects;

-- 3. إنشاء Policies جديدة (بترتيب الأهمية)

-- Policy 1: GM can do everything (ALL operations)
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

-- Policy 2: Anyone can read (public bucket)
CREATE POLICY "Anyone can read profile pictures"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'user-profiles');

-- Policy 3: Authenticated users can upload
CREATE POLICY "Authenticated users can upload profile pictures"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'user-profiles'
        AND auth.role() = 'authenticated'
    );

-- Policy 4: Authenticated users can update
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

-- Policy 5: Authenticated users can delete
CREATE POLICY "Authenticated users can delete profile pictures"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'user-profiles'
        AND auth.role() = 'authenticated'
    );

-- ============================================
-- 4. التحقق من النتيجة
-- ============================================
-- قم بتشغيل هذه الاستعلامات للتحقق:

-- تحقق من وجود Bucket:
-- SELECT id, name, public, file_size_limit, allowed_mime_types 
-- FROM storage.buckets 
-- WHERE id = 'user-profiles';

-- تحقق من وجود Policies:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies 
-- WHERE schemaname = 'storage' AND tablename = 'objects'
-- ORDER BY policyname;

-- ============================================
-- 5. ملاحظات مهمة
-- ============================================
-- 1. تأكد من أن المستخدم (GM) مسجل دخول قبل محاولة رفع الصور
-- 2. تأكد من أن Bucket موجود في Supabase Dashboard → Storage
-- 3. إذا استمرت المشكلة، تحقق من:
--    - أن auth.uid() يعيد ID المستخدم الحالي
--    - أن role في users table = 'gm'
--    - أن Bucket public = true

-- ============================================
-- END
-- ============================================

