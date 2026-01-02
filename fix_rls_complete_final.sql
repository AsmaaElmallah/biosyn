-- ============================================
-- Complete RLS Fix - Senior-Level Solution
-- ============================================
-- Problem: RLS policies prevent GM from creating/updating/deleting users
-- Root Cause: auth.uid() doesn't match users.id, and is_gm() function fails
-- Solution: Use multiple fallback methods to identify GM, simplify policies
-- Run this in Supabase SQL Editor

-- ============================================
-- Step 1: Drop all existing policies and functions
-- ============================================
DROP POLICY IF EXISTS "GM can read all users" ON users;
DROP POLICY IF EXISTS "GM can insert users" ON users;
DROP POLICY IF EXISTS "GM can update users" ON users;
DROP POLICY IF EXISTS "GM can delete users" ON users;
DROP POLICY IF EXISTS "Users can read own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;
DROP POLICY IF EXISTS "Allow username lookup for login" ON users;

-- Drop policies in plans and reports
DROP POLICY IF EXISTS "DM can read own plans" ON plans;
DROP POLICY IF EXISTS "DM can read own reports" ON reports;

-- Drop policies in notifications (MUST be dropped before dropping is_gm() function)
DROP POLICY IF EXISTS "Users can read their own notifications" ON notifications;
DROP POLICY IF EXISTS "Authenticated users can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "GMs can read their own notifications" ON notifications;
DROP POLICY IF EXISTS "Service role can insert notifications" ON notifications;
DROP POLICY IF EXISTS "GMs can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Public can read notifications" ON notifications;
DROP POLICY IF EXISTS "Authenticated can insert notifications" ON notifications;

-- Drop existing functions (now safe to drop since policies are removed)
DROP FUNCTION IF EXISTS public.get_auth_email() CASCADE;
DROP FUNCTION IF EXISTS public.is_gm() CASCADE;
DROP FUNCTION IF EXISTS public.debug_rls() CASCADE;

-- ============================================
-- Step 2: Create improved get_auth_email() function
-- ============================================
-- This function gets email from JWT claims or auth.users
-- Uses SECURITY DEFINER to access auth.users table
CREATE OR REPLACE FUNCTION public.get_auth_email()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    jwt_email TEXT;
    auth_email TEXT;
    current_uid UUID;
BEGIN
    -- Get current auth user ID
    current_uid := auth.uid();
    
    -- If no auth user, return NULL
    IF current_uid IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Method 1: Try to get email from JWT claims first (most reliable)
    BEGIN
        jwt_email := (current_setting('request.jwt.claims', true)::json->>'email');
        IF jwt_email IS NOT NULL AND jwt_email != '' THEN
            RETURN jwt_email;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        jwt_email := NULL;
    END;
    
    -- Method 2: Get email from auth.users table
    -- SECURITY DEFINER allows access to auth schema
    BEGIN
        SELECT email INTO auth_email
        FROM auth.users
        WHERE id = current_uid
        LIMIT 1;
        IF auth_email IS NOT NULL AND auth_email != '' THEN
            RETURN auth_email;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        auth_email := NULL;
    END;
    
    RETURN NULL;
END;
$$;

-- ============================================
-- Step 3: Create robust is_gm() function
-- ============================================
-- This function checks if current user is GM using multiple methods:
-- 1. Match auth.uid() with users.id
-- 2. Match auth.email() with users.email (PRIMARY METHOD)
-- 3. Use JWT claims directly (FALLBACK)
-- Uses SECURITY DEFINER to bypass RLS
CREATE OR REPLACE FUNCTION public.is_gm()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    user_role TEXT;
    current_auth_uid TEXT;
    current_auth_email TEXT;
    found_count INTEGER;
BEGIN
    -- Get current auth user ID
    current_auth_uid := auth.uid()::text;
    
    -- If no auth user, return false
    IF current_auth_uid IS NULL THEN
        RETURN false;
    END IF;
    
    -- Method 1: Try to match auth.uid() with users.id
    -- SECURITY DEFINER allows bypassing RLS for this check
    BEGIN
        SELECT role INTO user_role
        FROM public.users
        WHERE id::text = current_auth_uid
        LIMIT 1;
        
        IF user_role = 'gm' THEN
            RETURN true;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Ignore errors and continue to next method
        user_role := NULL;
    END;
    
    -- Method 2: Get email and match with users.email (PRIMARY METHOD)
    -- This is the most reliable method since email is consistent
    current_auth_email := public.get_auth_email();
    
    IF current_auth_email IS NOT NULL AND current_auth_email != '' THEN
        BEGIN
            SELECT role INTO user_role
            FROM public.users
            WHERE email = current_auth_email
            LIMIT 1;
            
            IF user_role = 'gm' THEN
                RETURN true;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- Ignore errors
            user_role := NULL;
        END;
    END IF;
    
    -- Method 3: Try to get email from JWT claims directly (fallback)
    BEGIN
        current_auth_email := (current_setting('request.jwt.claims', true)::json->>'email');
        IF current_auth_email IS NOT NULL AND current_auth_email != '' THEN
            SELECT role INTO user_role
            FROM public.users
            WHERE email = current_auth_email
            LIMIT 1;
            
            IF user_role = 'gm' THEN
                RETURN true;
            END IF;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Ignore errors
    END;
    
    -- Return false if not found or not GM
    RETURN false;
END;
$$;

-- ============================================
-- Step 4: Create debug_rls() function
-- ============================================
-- This function helps diagnose RLS issues
CREATE OR REPLACE FUNCTION public.debug_rls()
RETURNS TABLE(
    auth_uid TEXT,
    auth_email TEXT,
    users_id TEXT,
    users_email TEXT,
    users_role TEXT,
    is_gm_result BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    current_auth_uid TEXT;
    current_auth_email TEXT;
    current_users_id TEXT;
    current_users_email TEXT;
    current_users_role TEXT;
    gm_result BOOLEAN;
BEGIN
    current_auth_uid := auth.uid()::text;
    current_auth_email := public.get_auth_email();
    gm_result := public.is_gm();
    
    -- Try to find user by auth.uid()
    BEGIN
        SELECT id::text, email, role 
        INTO current_users_id, current_users_email, current_users_role
        FROM public.users
        WHERE id::text = current_auth_uid
        LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
        current_users_id := NULL;
        current_users_email := NULL;
        current_users_role := NULL;
    END;
    
    -- If not found by id, try by email
    IF current_users_id IS NULL AND current_auth_email IS NOT NULL THEN
        BEGIN
            SELECT id::text, email, role 
            INTO current_users_id, current_users_email, current_users_role
            FROM public.users
            WHERE email = current_auth_email
            LIMIT 1;
        EXCEPTION WHEN OTHERS THEN
            -- Keep NULL values
        END;
    END IF;
    
    RETURN QUERY SELECT 
        current_auth_uid,
        current_auth_email,
        current_users_id,
        current_users_email,
        current_users_role,
        gm_result;
END;
$$;

-- ============================================
-- Step 5: Create simplified and robust policies
-- ============================================

-- Policy 1: Allow username lookup for login (BEFORE authentication)
-- This must be permissive to allow login
DROP POLICY IF EXISTS "Allow username lookup for login" ON users;
CREATE POLICY "Allow username lookup for login"
    ON users FOR SELECT
    USING (true);  -- Allow reading username for login lookup

-- Policy 2: Users can read their own data
-- Simplified: Use auth.uid() OR email matching
DROP POLICY IF EXISTS "Users can read own data" ON users;
CREATE POLICY "Users can read own data"
    ON users FOR SELECT
    USING (
        auth.uid()::text = id::text
        OR (public.get_auth_email() IS NOT NULL AND public.get_auth_email() = users.email)
    );

-- Policy 3: GM can read all users
-- Uses is_gm() function which checks by email if id doesn't match
DROP POLICY IF EXISTS "GM can read all users" ON users;
CREATE POLICY "GM can read all users"
    ON users FOR SELECT
    USING (public.is_gm());

-- Policy 4: GM can insert users
-- CRITICAL: This allows GM to create new users
-- Uses is_gm() function which checks by email if id doesn't match
DROP POLICY IF EXISTS "GM can insert users" ON users;
CREATE POLICY "GM can insert users"
    ON users FOR INSERT
    WITH CHECK (public.is_gm());

-- Policy 5: GM can update any user
-- USING checks existing rows, WITH CHECK ensures updated rows pass
-- Uses is_gm() function which checks by email if id doesn't match
DROP POLICY IF EXISTS "GM can update users" ON users;
CREATE POLICY "GM can update users"
    ON users FOR UPDATE
    USING (public.is_gm())
    WITH CHECK (public.is_gm());

-- Policy 6: Users can update their own data
-- Simplified: Use auth.uid() OR email matching
DROP POLICY IF EXISTS "Users can update own data" ON users;
CREATE POLICY "Users can update own data"
    ON users FOR UPDATE
    USING (
        auth.uid()::text = id::text
        OR (public.get_auth_email() IS NOT NULL AND public.get_auth_email() = users.email)
    )
    WITH CHECK (
        auth.uid()::text = id::text
        OR (public.get_auth_email() IS NOT NULL AND public.get_auth_email() = users.email)
    );

-- Policy 7: GM can delete users
-- Uses is_gm() function which checks by email if id doesn't match
DROP POLICY IF EXISTS "GM can delete users" ON users;
CREATE POLICY "GM can delete users"
    ON users FOR DELETE
    USING (public.is_gm());

-- ============================================
-- Step 6: Fix policies for plans table
-- ============================================
-- Drop existing policies
DROP POLICY IF EXISTS "DM can read own plans" ON plans;
DROP POLICY IF EXISTS "Coaches can read own plans" ON plans;
DROP POLICY IF EXISTS "DM can insert own plans" ON plans;
DROP POLICY IF EXISTS "Coaches can insert own plans" ON plans;
DROP POLICY IF EXISTS "DM can update own plans" ON plans;
DROP POLICY IF EXISTS "Coaches can update own plans" ON plans;
DROP POLICY IF EXISTS "DM can delete own plans" ON plans;
DROP POLICY IF EXISTS "Coaches can delete own plans" ON plans;

-- Policy 1: SELECT - All coaches (DM/FT/PM/MSL) can read own plans, GM can read all
-- Note: dm_id in plans table stores the coach ID (DM, FT, PM, or MSL)
CREATE POLICY "Coaches can read own plans"
    ON plans FOR SELECT
    USING (
        -- All coaches (DM, FT, PM, MSL) can read their own plans (dm_id matches auth.uid())
        dm_id::text = auth.uid()::text
        -- OR GM can read ALL plans (using is_gm() function)
        OR public.is_gm()
    );

-- Policy 2: INSERT - All coaches (DM/FT/PM/MSL) can insert own plans, GM can insert any
CREATE POLICY "Coaches can insert own plans"
    ON plans FOR INSERT
    WITH CHECK (
        -- All coaches can insert plans where dm_id matches their auth.uid()
        dm_id::text = auth.uid()::text
        -- OR GM can insert any plan
        OR public.is_gm()
    );

-- Policy 3: UPDATE - All coaches (DM/FT/PM/MSL) can update own plans, GM can update any
CREATE POLICY "Coaches can update own plans"
    ON plans FOR UPDATE
    USING (
        -- All coaches can update plans where dm_id matches their auth.uid()
        dm_id::text = auth.uid()::text
        -- OR GM can update any plan
        OR public.is_gm()
    )
    WITH CHECK (
        -- Same conditions for WITH CHECK (ensures updated row also matches)
        dm_id::text = auth.uid()::text
        OR public.is_gm()
    );

-- Policy 4: DELETE - All coaches (DM/FT/PM/MSL) can delete own plans, GM can delete any
CREATE POLICY "Coaches can delete own plans"
    ON plans FOR DELETE
    USING (
        -- All coaches can delete plans where dm_id matches their auth.uid()
        dm_id::text = auth.uid()::text
        -- OR GM can delete any plan
        OR public.is_gm()
    );

-- ============================================
-- Step 7: Fix policies for reports table
-- ============================================
-- Drop existing policies
DROP POLICY IF EXISTS "DM can read own reports" ON reports;
DROP POLICY IF EXISTS "Users can insert their own reports" ON reports;
DROP POLICY IF EXISTS "Users can update their own reports" ON reports;
DROP POLICY IF EXISTS "Users can delete their own reports" ON reports;

-- Policy 1: SELECT - Users can read their own reports, GM can read all
CREATE POLICY "DM can read own reports"
    ON reports FOR SELECT
    USING (
        -- DM can read their own reports (dm_id matches auth.uid())
        dm_id::text = auth.uid()::text
        -- OR GM can read ALL reports (using is_gm() function)
        OR public.is_gm()
    );

-- Policy 2: INSERT - Users can insert their own reports, GM can insert any
CREATE POLICY "Users can insert their own reports"
    ON reports FOR INSERT
    WITH CHECK (
        -- User can insert reports where dm_id matches their auth.uid()
        dm_id::text = auth.uid()::text
        -- OR GM can insert any report
        OR public.is_gm()
    );

-- Policy 3: UPDATE - Users can update their own reports, GM can update any
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

-- Policy 4: DELETE - Users can delete their own reports, GM can delete any
CREATE POLICY "Users can delete their own reports"
    ON reports FOR DELETE
    USING (
        -- User can delete reports where dm_id matches their auth.uid()
        dm_id::text = auth.uid()::text
        -- OR GM can delete any report
        OR public.is_gm()
    );

-- ============================================
-- Step 8: Fix policies for notifications table
-- ============================================
-- Drop existing policies (already dropped in Step 1, but ensure cleanup)
DROP POLICY IF EXISTS "Users can read their own notifications" ON notifications;
DROP POLICY IF EXISTS "Authenticated users can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "GMs can read their own notifications" ON notifications;
DROP POLICY IF EXISTS "Service role can insert notifications" ON notifications;
DROP POLICY IF EXISTS "GMs can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Public can read notifications" ON notifications;
DROP POLICY IF EXISTS "Authenticated can insert notifications" ON notifications;

-- Policy 1: SELECT - Users can read their own notifications, GM can read all
CREATE POLICY "Users can read their own notifications"
    ON notifications FOR SELECT
    USING (
        -- User can read notifications where recipient_id matches their auth.uid()
        recipient_id::text = auth.uid()::text
        -- OR GM can read all notifications (for GM dashboard)
        OR public.is_gm()
    );

-- Policy 2: INSERT - Allow authenticated users to insert notifications
-- CRITICAL: This policy allows the app to insert notifications when reports are submitted
CREATE POLICY "Authenticated users can insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (
        -- Allow if user is authenticated (auth.uid() is not null)
        -- This is the key policy that allows notifications to be inserted
        auth.uid() IS NOT NULL
        -- OR if user is GM (for system notifications)
        OR public.is_gm()
    );

-- Policy 3: UPDATE - Users can update their own notifications (mark as read)
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
-- Step 9: Verify and test
-- ============================================
-- Test the functions
SELECT 
    auth.uid() as current_auth_uid,
    public.get_auth_email() as current_auth_email,
    public.is_gm() as is_gm_user;

-- Debug RLS (run this when logged in as GM)
SELECT * FROM public.debug_rls();

-- View all policies on users table
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'users'
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
-- CRITICAL: Verify Email Matching
-- ============================================
-- For this fix to work, the email in auth.users MUST match email in users table
-- 
-- To check if emails match:
-- SELECT 
--     au.id as auth_id,
--     au.email as auth_email,
--     u.id as users_id,
--     u.email as users_email,
--     u.role as users_role,
--     au.email = u.email as emails_match
-- FROM auth.users au
-- LEFT JOIN users u ON u.email = au.email
-- WHERE au.email = 'gm@biosyn.com';
--
-- If emails don't match, update one of them:
-- Option 1: Update users.email to match auth.users.email (RECOMMENDED)
-- UPDATE users 
-- SET email = (SELECT email FROM auth.users WHERE id = auth.uid() LIMIT 1)
-- WHERE role = 'gm' 
-- AND EXISTS (SELECT 1 FROM auth.users WHERE auth.users.id = auth.uid());
--
-- Option 2: Update auth.users.email (via Supabase Dashboard)
-- Go to Authentication → Users → Find GM user → Update email

-- ============================================
-- TROUBLESHOOTING GUIDE
-- ============================================
-- If is_gm() returns false:
-- 1. Check if email matches: SELECT * FROM public.debug_rls();
-- 2. Verify GM user exists: SELECT id, email, role FROM users WHERE role = 'gm';
-- 3. Check auth.users: SELECT id, email FROM auth.users WHERE email = 'gm@biosyn.com';
-- 4. If emails don't match, update users.email to match auth.users.email
--
-- If policies still fail:
-- 1. Ensure you're logged in via Supabase Auth (not just custom auth)
-- 2. Check if auth.uid() returns a value: SELECT auth.uid();
-- 3. Check if get_auth_email() returns a value: SELECT public.get_auth_email();
-- 4. Run debug_rls() to see full context: SELECT * FROM public.debug_rls();
--
-- After applying this script:
-- 1. Log out completely from the app
-- 2. Log in again as GM
-- 3. Test creating/updating/deleting users

