-- ============================================
-- Complete RLS Fix for Users Table
-- ============================================
-- Problem: After enabling RLS, GM cannot create, update, or delete users
-- Root Cause: is_gm() function uses auth.uid() which may not match users.id
-- Solution: Create multiple helper functions and comprehensive policies
-- Run this in Supabase SQL Editor

-- ============================================
-- Step 1: Drop all existing policies
-- ============================================
DROP POLICY IF EXISTS "GM can read all users" ON users;
DROP POLICY IF EXISTS "GM can insert users" ON users;
DROP POLICY IF EXISTS "GM can update users" ON users;
DROP POLICY IF EXISTS "GM can delete users" ON users;
DROP POLICY IF EXISTS "Users can read own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;
DROP POLICY IF EXISTS "Allow username lookup for login" ON users;

-- Also drop policies in plans and reports
DROP POLICY IF EXISTS "DM can read own plans" ON plans;
DROP POLICY IF EXISTS "DM can read own reports" ON reports;

-- ============================================
-- Step 2: Create improved helper function
-- ============================================
-- This function checks if the current user is GM by:
-- 1. First trying to match auth.uid() with users.id
-- 2. Then trying to match auth.jwt()->>'email' with users.email
-- 3. Using SECURITY DEFINER to bypass RLS for the check
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
BEGIN
    -- Get current auth user ID
    current_auth_uid := auth.uid()::text;
    
    -- Try to get email from JWT claims
    BEGIN
        current_auth_email := (current_setting('request.jwt.claims', true)::json->>'email');
    EXCEPTION WHEN OTHERS THEN
        current_auth_email := NULL;
    END;
    
    -- If no auth user, return false
    IF current_auth_uid IS NULL AND current_auth_email IS NULL THEN
        RETURN false;
    END IF;
    
    -- Try to get role from users table matching auth.uid()
    IF current_auth_uid IS NOT NULL THEN
        SELECT role INTO user_role
        FROM public.users
        WHERE id::text = current_auth_uid
        LIMIT 1;
        
        IF user_role = 'gm' THEN
            RETURN true;
        END IF;
    END IF;
    
    -- Try to get role from users table matching email
    IF current_auth_email IS NOT NULL THEN
        SELECT role INTO user_role
        FROM public.users
        WHERE email = current_auth_email
        LIMIT 1;
        
        IF user_role = 'gm' THEN
            RETURN true;
        END IF;
    END IF;
    
    -- Return false if not found or not GM
    RETURN false;
END;
$$;

-- ============================================
-- Step 3: Create function to get current user role
-- ============================================
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    user_role TEXT;
    current_auth_uid TEXT;
    current_auth_email TEXT;
BEGIN
    -- Get current auth user ID
    current_auth_uid := auth.uid()::text;
    
    -- Try to get email from JWT claims
    BEGIN
        current_auth_email := (current_setting('request.jwt.claims', true)::json->>'email');
    EXCEPTION WHEN OTHERS THEN
        current_auth_email := NULL;
    END;
    
    -- Try to get role from users table matching auth.uid()
    IF current_auth_uid IS NOT NULL THEN
        SELECT role INTO user_role
        FROM public.users
        WHERE id::text = current_auth_uid
        LIMIT 1;
        
        IF user_role IS NOT NULL THEN
            RETURN user_role;
        END IF;
    END IF;
    
    -- Try to get role from users table matching email
    IF current_auth_email IS NOT NULL THEN
        SELECT role INTO user_role
        FROM public.users
        WHERE email = current_auth_email
        LIMIT 1;
        
        IF user_role IS NOT NULL THEN
            RETURN user_role;
        END IF;
    END IF;
    
    RETURN NULL;
END;
$$;

-- ============================================
-- Step 4: Create comprehensive policies for users table
-- ============================================

-- Policy 1: Allow username lookup for login (BEFORE authentication)
-- This must be permissive to allow login
-- IMPORTANT: This policy allows reading users table for login purposes
DROP POLICY IF EXISTS "Allow username lookup for login" ON users;
CREATE POLICY "Allow username lookup for login"
    ON users FOR SELECT
    USING (true);  -- Allow reading username for login lookup

-- Policy 2: Users can read their own data
-- This allows users to read their own record
DROP POLICY IF EXISTS "Users can read own data" ON users;
CREATE POLICY "Users can read own data"
    ON users FOR SELECT
    USING (
        auth.uid()::text = id::text
        OR (
            -- Also allow if email matches (for cases where auth.uid() doesn't match)
            EXISTS (
                SELECT 1 FROM auth.users 
                WHERE auth.users.id = auth.uid() 
                AND auth.users.email = users.email
            )
        )
    );

-- Policy 3: GM can read all users
-- This allows GM to read all users
DROP POLICY IF EXISTS "GM can read all users" ON users;
CREATE POLICY "GM can read all users"
    ON users FOR SELECT
    USING (public.is_gm());

-- Policy 4: GM can insert users
-- IMPORTANT: This allows GM to create new users
-- WITH CHECK ensures the inserted row passes the policy
DROP POLICY IF EXISTS "GM can insert users" ON users;
CREATE POLICY "GM can insert users"
    ON users FOR INSERT
    WITH CHECK (public.is_gm());

-- Policy 5: GM can update any user
-- USING checks existing rows, WITH CHECK ensures updated rows pass
DROP POLICY IF EXISTS "GM can update users" ON users;
CREATE POLICY "GM can update users"
    ON users FOR UPDATE
    USING (public.is_gm())
    WITH CHECK (public.is_gm());

-- Policy 6: Users can update their own data
-- This allows users to update their own record
DROP POLICY IF EXISTS "Users can update own data" ON users;
CREATE POLICY "Users can update own data"
    ON users FOR UPDATE
    USING (
        auth.uid()::text = id::text
        OR (
            EXISTS (
                SELECT 1 FROM auth.users 
                WHERE auth.users.id = auth.uid() 
                AND auth.users.email = users.email
            )
        )
    )
    WITH CHECK (
        auth.uid()::text = id::text
        OR (
            EXISTS (
                SELECT 1 FROM auth.users 
                WHERE auth.users.id = auth.uid() 
                AND auth.users.email = users.email
            )
        )
    );

-- Policy 7: GM can delete users
-- This allows GM to delete any user
DROP POLICY IF EXISTS "GM can delete users" ON users;
CREATE POLICY "GM can delete users"
    ON users FOR DELETE
    USING (public.is_gm());

-- ============================================
-- Step 5: Fix policies for plans table
-- ============================================
DROP POLICY IF EXISTS "DM can read own plans" ON plans;
CREATE POLICY "DM can read own plans"
    ON plans FOR SELECT
    USING (
        dm_id::text = auth.uid()::text
        OR public.is_gm()
    );

-- ============================================
-- Step 6: Fix policies for reports table
-- ============================================
DROP POLICY IF EXISTS "DM can read own reports" ON reports;
CREATE POLICY "DM can read own reports"
    ON reports FOR SELECT
    USING (
        dm_id::text = auth.uid()::text
        OR public.is_gm()
    );

-- ============================================
-- Step 7: Verify the fix
-- ============================================
-- Test the helper functions
SELECT 
    auth.uid() as current_auth_uid,
    public.is_gm() as is_gm_user,
    public.get_current_user_role() as current_user_role;

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

-- ============================================
-- TROUBLESHOOTING GUIDE
-- ============================================
-- If GM still cannot create/update/delete users:
--
-- 1. Check if GM user exists in Supabase Auth:
--    SELECT id, email, created_at FROM auth.users WHERE email = 'gm@biosyn.com';
--
-- 2. Check if GM user exists in users table:
--    SELECT id, username, email, role FROM users WHERE role = 'gm';
--
-- 3. Check if auth.uid() matches users.id:
--    SELECT 
--        auth.uid() as auth_id,
--        u.id as users_id,
--        u.email as users_email,
--        u.role as users_role
--    FROM users u
--    WHERE u.role = 'gm';
--
-- 4. If auth.uid() doesn't match users.id, you have two options:
--    Option A: Update users.id to match auth.uid():
--        UPDATE users SET id = (SELECT id FROM auth.users WHERE email = users.email) WHERE role = 'gm';
--    
--    Option B: Make sure email matches:
--        The function will check email if id doesn't match
--
-- 5. Test the is_gm() function:
--    SELECT public.is_gm() as is_gm_result;
--    -- Should return true if logged in as GM
--
-- 6. Check current session:
--    SELECT auth.uid() as current_auth_uid, auth.email() as current_auth_email;
