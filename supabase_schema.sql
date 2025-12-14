-- ============================================
-- BIOSYN COACHING APP - SUPABASE DATABASE SCHEMA
-- ============================================
-- 
-- هذا الملف يحتوي على Schema كامل للـ Database
-- انسخه والصقه في Supabase Dashboard → SQL Editor
--
-- الخطوات:
-- 1. افتح Supabase Dashboard
-- 2. اذهب إلى SQL Editor
-- 3. انسخ كل محتوى هذا الملف
-- 4. الصقه في SQL Editor
-- 5. اضغط Run
-- ============================================

-- ============================================
-- 1. Enable UUID Extension
-- ============================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 2. USERS TABLE
-- ============================================
-- جدول المستخدمين (DM و GM)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL,
  username VARCHAR(100) UNIQUE NOT NULL,
  email VARCHAR(255),
  password VARCHAR(255), -- For development only - use password_hash in production
  password_hash VARCHAR(255), -- For production with bcrypt
  role VARCHAR(10) NOT NULL CHECK (role IN ('dm', 'gm', 'mr')),
  status VARCHAR(10) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 3. PLANS TABLE
-- ============================================
-- جدول الخطط الشهرية للـ DM
CREATE TABLE IF NOT EXISTS plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  dm_id UUID REFERENCES users(id) ON DELETE CASCADE,
  dm_name VARCHAR(255) NOT NULL,
  date DATE NOT NULL,
  mr_id VARCHAR(50) NOT NULL,
  mr_name VARCHAR(255) NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(dm_id, date, mr_id) -- منع تكرار نفس الخطة لنفس DM في نفس اليوم مع نفس MR
);

-- ============================================
-- 4. REPORTS TABLE
-- ============================================
-- جدول تقارير الكوتشينج
CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  date DATE NOT NULL,
  dm_id UUID REFERENCES users(id) ON DELETE CASCADE,
  dm_name VARCHAR(255) NOT NULL,
  mr_id VARCHAR(50) NOT NULL,
  mr_name VARCHAR(255) NOT NULL,
  
  -- Personal Attributes (Yes/No)
  punctuality VARCHAR(10) CHECK (punctuality IN ('Yes', 'No')),
  dress_code VARCHAR(10) CHECK (dress_code IN ('Yes', 'No')),
  time_management VARCHAR(10) CHECK (time_management IN ('Yes', 'No')),
  
  -- Performance Scores (1-6 scale)
  pharmacy_feedback VARCHAR(10),
  review_profile VARCHAR(10),
  brand_bonding VARCHAR(10),
  smart_objectives VARCHAR(10),
  opening VARCHAR(10),
  patient_profile VARCHAR(10),
  engaging VARCHAR(10),
  insightful_questions VARCHAR(10),
  active_listening VARCHAR(10),
  link_features VARCHAR(10),
  product_knowledge VARCHAR(10),
  e_detailing VARCHAR(10),
  answering_questions VARCHAR(10),
  summarize_call VARCHAR(10),
  ask_commitment VARCHAR(10),
  bridging VARCHAR(10),
  self_assessment VARCHAR(10),
  
  -- Feedback
  strengths TEXT,
  improvements TEXT,
  filled_with_mr VARCHAR(10) CHECK (filled_with_mr IN ('Yes', 'No')),
  
  -- Metadata
  average_score DECIMAL(3,2),
  synced BOOLEAN DEFAULT true, -- Always true in Supabase (local DB handles offline)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 5. INDEXES FOR PERFORMANCE
-- ============================================
-- Indexes للـ Reports
CREATE INDEX IF NOT EXISTS idx_reports_dm_id ON reports(dm_id);
CREATE INDEX IF NOT EXISTS idx_reports_date ON reports(date);
CREATE INDEX IF NOT EXISTS idx_reports_mr_id ON reports(mr_id);
CREATE INDEX IF NOT EXISTS idx_reports_dm_date ON reports(dm_id, date); -- Composite index

-- Indexes للـ Plans
CREATE INDEX IF NOT EXISTS idx_plans_dm_id ON plans(dm_id);
CREATE INDEX IF NOT EXISTS idx_plans_date ON plans(date);
CREATE INDEX IF NOT EXISTS idx_plans_dm_date ON plans(dm_id, date); -- Composite index
CREATE INDEX IF NOT EXISTS idx_plans_status ON plans(status);

-- Indexes للـ Users
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

-- ============================================
-- 6. FUNCTIONS FOR AUTO-UPDATE TIMESTAMPS
-- ============================================
-- Function لتحديث updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ============================================
-- 7. TRIGGERS FOR AUTO-UPDATE TIMESTAMPS
-- ============================================
-- Trigger للـ Users
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger للـ Plans
DROP TRIGGER IF EXISTS update_plans_updated_at ON plans;
CREATE TRIGGER update_plans_updated_at 
    BEFORE UPDATE ON plans
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger للـ Reports
DROP TRIGGER IF EXISTS update_reports_updated_at ON reports;
CREATE TRIGGER update_reports_updated_at 
    BEFORE UPDATE ON reports
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================
-- تفعيل RLS على جميع الجداول
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 9. USERS TABLE POLICIES
-- ============================================
-- Policy: Users can read their own data
CREATE POLICY "Users can read own data"
    ON users FOR SELECT
    USING (auth.uid()::text = id::text);

-- Policy: GM can read all users
CREATE POLICY "GM can read all users"
    ON users FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE id::text = auth.uid()::text
            AND role = 'gm'
        )
    );

-- Policy: GM can insert users
CREATE POLICY "GM can insert users"
    ON users FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users
            WHERE id::text = auth.uid()::text
            AND role = 'gm'
        )
    );

-- Policy: GM can update users
CREATE POLICY "GM can update users"
    ON users FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE id::text = auth.uid()::text
            AND role = 'gm'
        )
    );

-- ============================================
-- 10. PLANS TABLE POLICIES
-- ============================================
-- Policy: DM can read own plans
CREATE POLICY "DM can read own plans"
    ON plans FOR SELECT
    USING (
        dm_id::text = auth.uid()::text
        OR EXISTS (
            SELECT 1 FROM users
            WHERE id::text = auth.uid()::text
            AND role = 'gm'
        )
    );

-- Policy: DM can insert own plans
CREATE POLICY "DM can insert own plans"
    ON plans FOR INSERT
    WITH CHECK (dm_id::text = auth.uid()::text);

-- Policy: DM can update own plans
CREATE POLICY "DM can update own plans"
    ON plans FOR UPDATE
    USING (dm_id::text = auth.uid()::text);

-- Policy: DM can delete own plans
CREATE POLICY "DM can delete own plans"
    ON plans FOR DELETE
    USING (dm_id::text = auth.uid()::text);

-- ============================================
-- 11. REPORTS TABLE POLICIES
-- ============================================
-- Policy: DM can read own reports
CREATE POLICY "DM can read own reports"
    ON reports FOR SELECT
    USING (
        dm_id::text = auth.uid()::text
        OR EXISTS (
            SELECT 1 FROM users
            WHERE id::text = auth.uid()::text
            AND role = 'gm'
        )
    );

-- Policy: DM can insert own reports
CREATE POLICY "DM can insert own reports"
    ON reports FOR INSERT
    WITH CHECK (dm_id::text = auth.uid()::text);

-- Policy: DM can update own reports
CREATE POLICY "DM can update own reports"
    ON reports FOR UPDATE
    USING (dm_id::text = auth.uid()::text);

-- Policy: DM can delete own reports
CREATE POLICY "DM can delete own reports"
    ON reports FOR DELETE
    USING (dm_id::text = auth.uid()::text);

-- ============================================
-- 12. SAMPLE DATA (Optional - for testing)
-- ============================================
-- يمكنك إضافة بيانات تجريبية هنا للاختبار
-- ملاحظة: في Production، احذف هذا القسم

-- Insert sample GM user
-- Password: admin123 (NOT SECURE - for development only)
INSERT INTO users (name, username, email, password, role, status)
VALUES ('General Manager', 'gm', 'gm@biosyn.com', 'admin123', 'gm', 'active')
ON CONFLICT (username) DO NOTHING;

-- Insert sample DM user
-- Password: dm123 (NOT SECURE - for development only)
INSERT INTO users (name, username, email, password, role, status)
VALUES ('District Manager', 'dm', 'dm@biosyn.com', 'dm123', 'dm', 'active')
ON CONFLICT (username) DO NOTHING;

-- ============================================
-- 13. VERIFICATION QUERIES
-- ============================================
-- استخدم هذه الـ Queries للتحقق من نجاح الإعداد:

-- Check tables
-- SELECT table_name FROM information_schema.tables 
-- WHERE table_schema = 'public' AND table_name IN ('users', 'plans', 'reports');

-- Check indexes
-- SELECT indexname FROM pg_indexes 
-- WHERE tablename IN ('users', 'plans', 'reports');

-- Check RLS policies
-- SELECT tablename, policyname FROM pg_policies 
-- WHERE tablename IN ('users', 'plans', 'reports');

-- Check sample data
-- SELECT id, name, username, role, status FROM users;

-- ============================================
-- END OF SCHEMA
-- ============================================
-- 
-- بعد تشغيل هذا الـ Script:
-- 1. تحقق من Tables في Supabase Dashboard → Table Editor
-- 2. تحقق من RLS Policies في Settings → Authentication → Policies
-- 3. اختبر الـ API في API Docs
-- ============================================

