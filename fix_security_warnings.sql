-- ============================================
-- Fix Security Warnings in Supabase
-- ============================================
-- This script fixes:
-- 1. Function Search Path Mutable warnings
-- 2. Leaked Password Protection
-- Run this in Supabase SQL Editor

-- ============================================
-- 1. Fix Function Search Path Mutable
-- ============================================
-- This prevents SQL injection attacks by setting a fixed search_path

-- Fix update_updated_at_column function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- Fix update_notifications_updated_at function
CREATE OR REPLACE FUNCTION update_notifications_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- ============================================
-- 2. Enable Leaked Password Protection
-- ============================================
-- This enables Supabase's built-in protection against leaked passwords
-- Note: This is done via Supabase Dashboard, not SQL
-- Go to: Authentication > Settings > Password Protection
-- Enable "Check for leaked passwords"

-- ============================================
-- Verify Functions are Fixed
-- ============================================
-- Check function definitions
SELECT 
    proname as function_name,
    prosecdef as security_definer,
    proconfig as search_path_config
FROM pg_proc
WHERE proname IN ('update_updated_at_column', 'update_notifications_updated_at')
    AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

