-- ============================================
-- Fix RLS Policies for Plans Table
-- ============================================
-- Problem: Plans cannot be saved (INSERT) or updated (UPDATE) or deleted (DELETE) in Supabase
-- Root Cause: Missing RLS policies for INSERT, UPDATE, DELETE operations on plans table
-- Solution: Add comprehensive RLS policies for all CRUD operations on plans table
-- Run this in Supabase SQL Editor AFTER running fix_rls_complete_final.sql

-- ============================================
-- Step 1: Drop existing policies (if any)
-- ============================================
DROP POLICY IF EXISTS "DM can read own plans" ON plans;
DROP POLICY IF EXISTS "Coaches can read own plans" ON plans;
DROP POLICY IF EXISTS "DM can insert own plans" ON plans;
DROP POLICY IF EXISTS "Coaches can insert own plans" ON plans;
DROP POLICY IF EXISTS "DM can update own plans" ON plans;
DROP POLICY IF EXISTS "Coaches can update own plans" ON plans;
DROP POLICY IF EXISTS "DM can delete own plans" ON plans;
DROP POLICY IF EXISTS "Coaches can delete own plans" ON plans;

-- ============================================
-- Step 2: Create comprehensive policies for plans table
-- ============================================

-- Policy 1: SELECT - All coaches (DM/FT/PM/MSL) can read own plans, GM can read all
-- Note: dm_id in plans table stores the coach ID (DM, FT, PM, or MSL)
-- This policy allows:
-- - DM/FT/PM/MSL to read plans where dm_id matches their auth.uid()
-- - GM to read ALL plans
CREATE POLICY "Coaches can read own plans"
    ON plans FOR SELECT
    USING (
        -- All coaches (DM, FT, PM, MSL) can read their own plans (dm_id matches auth.uid())
        dm_id::text = auth.uid()::text
        -- OR GM can read ALL plans (using is_gm() function)
        OR public.is_gm()
    );

-- Policy 2: INSERT - All coaches (DM/FT/PM/MSL) can insert own plans, GM can insert any
-- This allows users to create plans where dm_id matches their auth.uid()
-- Works for:
-- - DM: dm_id = auth.uid() (DM's own ID)
-- - FT: dm_id = auth.uid() (FT's own ID)
-- - PM: dm_id = auth.uid() (PM's own ID, stored as coachId)
-- - MSL: dm_id = auth.uid() (MSL's own ID, stored as coachId)
CREATE POLICY "Coaches can insert own plans"
    ON plans FOR INSERT
    WITH CHECK (
        -- All coaches can insert plans where dm_id matches their auth.uid()
        dm_id::text = auth.uid()::text
        -- OR GM can insert any plan
        OR public.is_gm()
    );

-- Policy 3: UPDATE - All coaches (DM/FT/PM/MSL) can update own plans, GM can update any
-- This allows users to update plans where dm_id matches their auth.uid()
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
-- This allows users to delete plans where dm_id matches their auth.uid()
CREATE POLICY "Coaches can delete own plans"
    ON plans FOR DELETE
    USING (
        -- All coaches can delete plans where dm_id matches their auth.uid()
        dm_id::text = auth.uid()::text
        -- OR GM can delete any plan
        OR public.is_gm()
    );

-- ============================================
-- Step 3: Verify policies
-- ============================================
-- View all policies on plans table
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'plans'
ORDER BY policyname;

-- ============================================
-- Step 4: Test queries (run these when logged in as DM or GM)
-- ============================================
-- Test 1: Check if coach (DM/FT/PM/MSL) can read own plans
-- SELECT COUNT(*) FROM plans WHERE dm_id = auth.uid()::text;
-- Should return count of plans for current user (works for DM, FT, PM, MSL)

-- Test 2: Check if GM can read all plans
-- SELECT COUNT(*) FROM plans;
-- Should return count of all plans (if logged in as GM)

-- Test 3: Check is_gm() function
-- SELECT public.is_gm() as is_gm_result;
-- Should return: true (if logged in as GM)

-- Test 4: Debug RLS
-- SELECT * FROM public.debug_rls();

-- ============================================
-- TROUBLESHOOTING
-- ============================================
-- If plans still cannot be saved/updated/deleted:
-- 1. Verify is_gm() returns true (if GM): SELECT public.is_gm();
-- 2. Check email matching: SELECT * FROM public.debug_rls();
-- 3. Verify policies exist: SELECT policyname FROM pg_policies WHERE tablename = 'plans';
-- 4. Ensure you're logged in via Supabase Auth (not just custom auth)
-- 5. Log out and log in again after applying this script
-- 6. Check if dm_id in the plan matches auth.uid() (for all coaches: DM, FT, PM, MSL)
-- Note: For PM/MSL, dm_id stores their coachId (which equals auth.uid())
-- 7. Verify RLS is enabled: SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'plans';

