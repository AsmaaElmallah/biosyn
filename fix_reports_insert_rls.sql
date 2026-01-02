-- ============================================
-- Fix RLS Policy for Reports INSERT
-- ============================================
-- Problem: Users cannot insert reports into Supabase
-- Root Cause: No RLS policy exists for INSERT operations on reports table
-- Solution: Add INSERT policy that allows users to insert their own reports
-- Run this in Supabase SQL Editor AFTER running fix_rls_complete_final.sql and fix_reports_notifications_rls.sql

-- ============================================
-- Step 1: Add INSERT policy for reports table
-- ============================================
-- Drop existing INSERT policy if exists
DROP POLICY IF EXISTS "Users can insert their own reports" ON reports;
DROP POLICY IF EXISTS "DM can insert reports" ON reports;
DROP POLICY IF EXISTS "Authenticated users can insert reports" ON reports;

-- Create INSERT policy that allows:
-- 1. Users to insert reports where dm_id matches their auth.uid()
-- 2. GM to insert any report (using is_gm() function)
CREATE POLICY "Users can insert their own reports"
    ON reports FOR INSERT
    WITH CHECK (
        -- User can insert reports where dm_id matches their auth.uid()
        dm_id::text = auth.uid()::text
        -- OR GM can insert any report
        OR public.is_gm()
    );

-- ============================================
-- Step 2: Add UPDATE policy for reports table (if needed)
-- ============================================
-- Drop existing UPDATE policy if exists
DROP POLICY IF EXISTS "Users can update their own reports" ON reports;
DROP POLICY IF EXISTS "DM can update reports" ON reports;

-- Create UPDATE policy that allows:
-- 1. Users to update reports where dm_id matches their auth.uid()
-- 2. GM to update any report (using is_gm() function)
CREATE POLICY "Users can update their own reports"
    ON reports FOR UPDATE
    USING (
        -- User can update reports where dm_id matches their auth.uid()
        dm_id::text = auth.uid()::text
        -- OR GM can update any report
        OR public.is_gm()
    )
    WITH CHECK (
        -- Same conditions for WITH CHECK
        dm_id::text = auth.uid()::text
        OR public.is_gm()
    );

-- ============================================
-- Step 3: Add DELETE policy for reports table (if needed)
-- ============================================
-- Drop existing DELETE policy if exists
DROP POLICY IF EXISTS "Users can delete their own reports" ON reports;
DROP POLICY IF EXISTS "DM can delete reports" ON reports;

-- Create DELETE policy that allows:
-- 1. Users to delete reports where dm_id matches their auth.uid()
-- 2. GM to delete any report (using is_gm() function)
CREATE POLICY "Users can delete their own reports"
    ON reports FOR DELETE
    USING (
        -- User can delete reports where dm_id matches their auth.uid()
        dm_id::text = auth.uid()::text
        -- OR GM can delete any report
        OR public.is_gm()
    );

-- ============================================
-- Step 4: Verify policies
-- ============================================
-- View all policies on reports table
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'reports'
ORDER BY cmd, policyname;

-- ============================================
-- Step 5: Test queries (run these when logged in as a user)
-- ============================================
-- Test 1: Check if user can insert a report
-- INSERT INTO reports (dm_id, dm_name, mr_id, mr_name, date, coach_role, average_score, synced)
-- VALUES (auth.uid(), 'Test DM', '00000000-0000-0000-0000-000000000000', 'Test MR', '2026-01-01', 'dm', 0, true);
-- Should succeed

-- Test 2: Check if GM can insert a report
-- SELECT public.is_gm() as is_gm_result;
-- Should return: true (if logged in as GM)

-- Test 3: Check if user can read their own reports
-- SELECT COUNT(*) FROM reports WHERE dm_id::text = auth.uid()::text;
-- Should return count of user's reports

-- Test 4: Check if GM can read all reports
-- SELECT COUNT(*) FROM reports;
-- Should return count of all reports

-- ============================================
-- TROUBLESHOOTING
-- ============================================
-- If users still cannot insert reports:
-- 1. Verify auth.uid() returns a value: SELECT auth.uid();
-- 2. Check if dm_id matches auth.uid(): SELECT auth.uid()::text = 'your-dm-id';
-- 3. Verify is_gm() returns true for GM: SELECT public.is_gm();
-- 4. Check email matching: SELECT * FROM public.debug_rls();
-- 5. Verify policies exist: SELECT policyname, cmd FROM pg_policies WHERE tablename = 'reports';
-- 6. Ensure you're logged in via Supabase Auth (not just custom auth)
-- 7. Log out and log in again after applying this script

-- ============================================
-- IMPORTANT NOTES
-- ============================================
-- 1. The INSERT policy checks that dm_id matches auth.uid()
--    This means the user must be authenticated in Supabase Auth
--    and their auth.uid() must match the dm_id in the report
--
-- 2. For GM, is_gm() function is used to allow inserting any report
--
-- 3. If auth.uid() doesn't match users.id, the INSERT will fail
--    Make sure users are logged in via Supabase Auth
--
-- 4. After applying this script, users must log out and log in again
--    to refresh their authentication session

