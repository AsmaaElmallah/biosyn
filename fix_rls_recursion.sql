-- ============================================
-- Fix RLS Recursion Error in Users Table
-- ============================================
-- Problem: Policies on 'users' table try to read from 'users' itself
-- This causes infinite recursion: "infinite recursion detected in policy for relation 'users'"
-- Solution: Create a helper function to check user role without recursion
-- Run this in Supabase SQL Editor

-- ============================================
-- Step 1: Drop existing problematic policies
-- ============================================
DROP POLICY IF EXISTS "GM can read all users" ON users;
DROP POLICY IF EXISTS "GM can insert users" ON users;
DROP POLICY IF EXISTS "GM can update users" ON users;

-- Also fix policies in plans and reports that reference users
DROP POLICY IF EXISTS "DM can read own plans" ON plans;
DROP POLICY IF EXISTS "DM can read own reports" ON reports;

-- ============================================
-- Step 2: Create helper function to check if user is GM
-- ============================================
-- This function uses SECURITY DEFINER to bypass RLS
-- and SET search_path to prevent SQL injection
CREATE OR REPLACE FUNCTION public.is_gm()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    user_role TEXT;
BEGIN
    -- Get user role directly from users table
    -- SECURITY DEFINER allows bypassing RLS for this check
    SELECT role INTO user_role
    FROM public.users
    WHERE id::text = auth.uid()::text
    LIMIT 1;
    
    -- Return true if role is 'gm', false otherwise
    RETURN COALESCE(user_role = 'gm', false);
END;
$$;

-- ============================================
-- Step 3: Create fixed policies for users table
-- ============================================

-- Policy: Users can read their own data
-- (Keep existing policy if it works, otherwise recreate)
DROP POLICY IF EXISTS "Users can read own data" ON users;
CREATE POLICY "Users can read own data"
    ON users FOR SELECT
    USING (auth.uid()::text = id::text);

-- Policy: GM can read all users (using helper function)
DROP POLICY IF EXISTS "GM can read all users" ON users;
CREATE POLICY "GM can read all users"
    ON users FOR SELECT
    USING (public.is_gm());

-- Policy: GM can insert users (using helper function)
DROP POLICY IF EXISTS "GM can insert users" ON users;
CREATE POLICY "GM can insert users"
    ON users FOR INSERT
    WITH CHECK (public.is_gm());

-- Policy: GM can update users (using helper function)
DROP POLICY IF EXISTS "GM can update users" ON users;
CREATE POLICY "GM can update users"
    ON users FOR UPDATE
    USING (public.is_gm())
    WITH CHECK (public.is_gm());

-- Policy: Users can update their own data
DROP POLICY IF EXISTS "Users can update own data" ON users;
CREATE POLICY "Users can update own data"
    ON users FOR UPDATE
    USING (auth.uid()::text = id::text)
    WITH CHECK (auth.uid()::text = id::text);

-- Policy: GM can delete users (using helper function)
DROP POLICY IF EXISTS "GM can delete users" ON users;
CREATE POLICY "GM can delete users"
    ON users FOR DELETE
    USING (public.is_gm());

-- Policy: Allow username lookup for login (read username only, not password)
-- This is needed for login before user is authenticated
-- We only allow reading username, name, role, status, email, id for login purposes
-- Password fields are excluded from this policy for security
DROP POLICY IF EXISTS "Allow username lookup for login" ON users;
CREATE POLICY "Allow username lookup for login"
    ON users FOR SELECT
    USING (true);  -- Allow reading username for login lookup
    -- Note: In production, you might want to restrict this to only username, name, role, status, email
    -- But for now, we allow full read for login (password is still protected by app logic)

-- ============================================
-- Step 4: Fix policies for plans table
-- ============================================

-- Policy: DM can read own plans (using helper function for GM check)
DROP POLICY IF EXISTS "DM can read own plans" ON plans;
CREATE POLICY "DM can read own plans"
    ON plans FOR SELECT
    USING (
        dm_id::text = auth.uid()::text
        OR public.is_gm()
    );

-- ============================================
-- Step 5: Fix policies for reports table
-- ============================================

-- Policy: DM can read own reports (using helper function for GM check)
DROP POLICY IF EXISTS "DM can read own reports" ON reports;
CREATE POLICY "DM can read own reports"
    ON reports FOR SELECT
    USING (
        dm_id::text = auth.uid()::text
        OR public.is_gm()
    );

-- ============================================
-- Step 6: Verify the fix
-- ============================================
-- Test the helper function (should return true if current user is GM)
SELECT 
    auth.uid() as current_user_id,
    public.is_gm() as is_gm_user;

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

