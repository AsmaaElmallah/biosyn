-- ============================================
-- Fix RLS Policies for Reports and Notifications
-- ============================================
-- Problem: GM cannot fetch reports or notifications after RLS fix
-- Root Cause: RLS policies on reports and notifications tables don't use is_gm() correctly
-- Solution: Update policies to use is_gm() function properly
-- Run this in Supabase SQL Editor AFTER running fix_rls_complete_final.sql

-- ============================================
-- Step 1: Fix policies for reports table
-- ============================================
-- Drop existing policy
DROP POLICY IF EXISTS "DM can read own reports" ON reports;

-- Create improved policy that allows:
-- 1. DM to read their own reports (dm_id matches auth.uid())
-- 2. GM to read ALL reports (using is_gm() function)
-- Simplified to avoid recursion
CREATE POLICY "DM can read own reports"
    ON reports FOR SELECT
    USING (
        -- DM can read their own reports
        dm_id::text = auth.uid()::text
        -- OR GM can read all reports
        OR public.is_gm()
    );

-- ============================================
-- Step 2: Fix policies for notifications table
-- ============================================
-- Drop existing policies
DROP POLICY IF EXISTS "GMs can read their own notifications" ON notifications;
DROP POLICY IF EXISTS "Service role can insert notifications" ON notifications;
DROP POLICY IF EXISTS "GMs can update their own notifications" ON notifications;

-- Policy 1: Users can read their own notifications
-- This allows users to read notifications where recipient_id matches their id or email
-- Simplified to avoid recursion
CREATE POLICY "Users can read their own notifications"
    ON notifications FOR SELECT
    USING (
        -- User can read notifications where recipient_id matches their auth.uid()
        recipient_id::text = auth.uid()::text
        -- OR GM can read all notifications (for GM dashboard)
        OR public.is_gm()
    );

-- Policy 2: Allow inserting notifications
-- This allows the system to insert notifications for any user
-- We use is_gm() OR true to allow inserts from authenticated users
-- (In practice, only the app inserts notifications, and it's authenticated)
CREATE POLICY "Authenticated users can insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (
        -- Allow if user is authenticated (auth.uid() is not null)
        auth.uid() IS NOT NULL
        -- OR if user is GM (for system notifications)
        OR public.is_gm()
    );

-- Policy 3: Users can update their own notifications (mark as read)
-- Simplified to avoid recursion
CREATE POLICY "Users can update their own notifications"
    ON notifications FOR UPDATE
    USING (
        -- User can update notifications where recipient_id matches their auth.uid()
        recipient_id::text = auth.uid()::text
        -- OR GM can update any notification
        OR public.is_gm()
    )
    WITH CHECK (
        -- Same conditions for WITH CHECK
        recipient_id::text = auth.uid()::text
        OR public.is_gm()
    );

-- ============================================
-- Step 3: Verify policies
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
ORDER BY policyname;

-- View all policies on notifications table
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY policyname;

-- ============================================
-- Step 4: Test queries (run these when logged in as GM)
-- ============================================
-- Test 1: Check if GM can read reports
-- SELECT COUNT(*) FROM reports;
-- Should return count of all reports

-- Test 2: Check if GM can read notifications
-- SELECT COUNT(*) FROM notifications;
-- Should return count of all notifications

-- Test 3: Check is_gm() function
-- SELECT public.is_gm() as is_gm_result;
-- Should return: true

-- Test 4: Debug RLS
-- SELECT * FROM public.debug_rls();

-- ============================================
-- TROUBLESHOOTING
-- ============================================
-- If GM still cannot read reports/notifications:
-- 1. Verify is_gm() returns true: SELECT public.is_gm();
-- 2. Check email matching: SELECT * FROM public.debug_rls();
-- 3. Verify policies exist: SELECT policyname FROM pg_policies WHERE tablename IN ('reports', 'notifications');
-- 4. Ensure you're logged in via Supabase Auth (not just custom auth)
-- 5. Log out and log in again after applying this script

