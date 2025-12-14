/// Supabase Configuration
/// 
/// بعد إنشاء Supabase Project:
/// 1. اذهب إلى Settings → API
/// 2. انسخ Project URL و anon key
/// 3. ضعهم هنا

class SupabaseConfig {
  // Supabase Project URL
  // تم استخراجه من JWT token: ref = noiuxsaajphioculuvhx
  static const String supabaseUrl = 'https://noiuxsaajphioculuvhx.supabase.co';
  
  // Supabase Anon Key (Public Key)
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5vaXV4c2FhanBoaW9jdWx1dmh4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3MjcwMjgsImV4cCI6MjA4MTMwMzAyOH0.5VZglUszExGjv_9thfWLmB2x_0lhka67sHA4A3uEVPA';
  
  /// Check if Supabase is configured
  static bool get isConfigured {
    return supabaseUrl != 'YOUR_SUPABASE_URL' && 
           supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';
  }
}

