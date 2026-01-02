-- ============================================
-- Enable Row Level Security (RLS) on all tables
-- ============================================
-- This script enables RLS on users, reports, and plans tables
-- Run this in Supabase SQL Editor

-- Enable RLS on users table
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Enable RLS on reports table
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Enable RLS on plans table
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;

-- ============================================
-- Verify RLS is enabled
-- ============================================
-- Check if RLS is enabled (should return 't' for true)
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public' 
    AND tablename IN ('users', 'reports', 'plans')
ORDER BY tablename;

