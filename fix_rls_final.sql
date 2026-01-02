-- ============================================
-- Final RLS Fix - Using Email for Authentication
-- ============================================
-- Problem: auth.uid() doesn't match users.id
-- Solution: Use auth.email() to match users.email
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
-- Step 2: Create helper function to get auth email
-- ============================================
-- This function gets email from JWT claims or auth.users
-- MUST be created before is_gm() function
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
-- Step 3: Create improved is_gm() function
-- ============================================
-- This function checks if current user is GM by:
-- 1. Matching auth.uid() with users.id (if they match)
-- 2. Matching auth.email() with users.email (primary method)
-- 3. Using SECURITY DEFINER to bypass RLS
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
-- Step 4: Create debug function (optional, for troubleshooting)
-- ============================================
-- This function helps debug RLS issues
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
-- Step 5: Create comprehensive policies
-- ============================================

-- Policy 1: Allow username lookup for login (BEFORE authentication)
DROP POLICY IF EXISTS "Allow username lookup for login" ON users;
CREATE POLICY "Allow username lookup for login"
    ON users FOR SELECT
    USING (true);

-- Policy 2: Users can read their own data
DROP POLICY IF EXISTS "Users can read own data" ON users;
CREATE POLICY "Users can read own data"
    ON users FOR SELECT
    USING (
        auth.uid()::text = id::text
        OR EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND auth.users.email = users.email
        )
    );

-- Policy 3: GM can read all users
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
-- Uses is_gm() function which checks by email if id doesn't match
DROP POLICY IF EXISTS "GM can update users" ON users;
CREATE POLICY "GM can update users"
    ON users FOR UPDATE
    USING (public.is_gm())
    WITH CHECK (public.is_gm());

-- Policy 6: Users can update their own data
DROP POLICY IF EXISTS "Users can update own data" ON users;
CREATE POLICY "Users can update own data"
    ON users FOR UPDATE
    USING (
        auth.uid()::text = id::text
        OR EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND auth.users.email = users.email
        )
    )
    WITH CHECK (
        auth.uid()::text = id::text
        OR EXISTS (
            SELECT 1 FROM auth.users 
            WHERE auth.users.id = auth.uid() 
            AND auth.users.email = users.email
        )
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
DROP POLICY IF EXISTS "DM can read own plans" ON plans;
CREATE POLICY "DM can read own plans"
    ON plans FOR SELECT
    USING (
        dm_id::text = auth.uid()::text
        OR public.is_gm()
    );

-- ============================================
-- Step 7: Fix policies for reports table
-- ============================================
DROP POLICY IF EXISTS "DM can read own reports" ON reports;
CREATE POLICY "DM can read own reports"
    ON reports FOR SELECT
    USING (
        dm_id::text = auth.uid()::text
        OR public.is_gm()
    );

-- ============================================
-- Step 8: Verify and test
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

-- ============================================
-- DIAGNOSTIC QUERIES
-- ============================================
-- Run these queries to diagnose issues:

-- 1. Check GM user in auth.users:
-- SELECT id, email, created_at FROM auth.users WHERE email = 'gm@biosyn.com';

-- 2. Check GM user in users table:
-- SELECT id, username, email, role FROM users WHERE role = 'gm';

-- 3. Check if auth.uid() matches:
-- SELECT 
--     auth.uid() as auth_id,
--     u.id as users_id,
--     u.email as users_email,
--     u.role as users_role,
--     (SELECT email FROM auth.users WHERE id = auth.uid() LIMIT 1) as auth_email
-- FROM users u
-- WHERE u.role = 'gm';

-- 4. Test is_gm() function:
-- SELECT public.is_gm() as is_gm_result;

-- 5. Debug RLS (run this when logged in as GM):
-- SELECT * FROM public.debug_rls();

-- ============================================
-- CRITICAL: Make sure email matches!
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
-- Option 1: Update users.email to match auth.users.email
-- UPDATE users 
-- SET email = (SELECT email FROM auth.users WHERE id = auth.uid())
-- WHERE role = 'gm' 
-- AND EXISTS (SELECT 1 FROM auth.users WHERE auth.users.id = auth.uid());
--
-- Option 2: Update auth.users.email (via Supabase Dashboard)
-- Go to Authentication → Users → Find GM user → Update email

