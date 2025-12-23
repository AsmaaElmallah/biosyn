-- Create notifications table for time/date change alerts
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- GM user ID
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- Coach ID (DM/FT/PM/MSL)
  sender_name TEXT NOT NULL, -- Coach name
  sender_role TEXT NOT NULL CHECK (sender_role IN ('dm', 'ft', 'pm', 'msl')), -- Coach role
  notification_type TEXT NOT NULL DEFAULT 'time_change', -- Type of notification
  title TEXT NOT NULL, -- Notification title
  message TEXT NOT NULL, -- Notification message
  report_id UUID REFERENCES reports(id) ON DELETE CASCADE, -- Related report ID
  read BOOLEAN DEFAULT FALSE, -- Whether notification has been read
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- Enable RLS (Row Level Security)
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: GMs can read their own notifications
CREATE POLICY "GMs can read their own notifications"
  ON notifications
  FOR SELECT
  USING (
    recipient_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.role = 'gm'
    )
  );

-- Policy: System can insert notifications (via service role)
CREATE POLICY "Service role can insert notifications"
  ON notifications
  FOR INSERT
  WITH CHECK (true);

-- Policy: GMs can update their own notifications (mark as read)
CREATE POLICY "GMs can update their own notifications"
  ON notifications
  FOR UPDATE
  USING (
    recipient_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM users 
      WHERE users.id = auth.uid() 
      AND users.role = 'gm'
    )
  );

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_notifications_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at
CREATE TRIGGER update_notifications_updated_at
  BEFORE UPDATE ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION update_notifications_updated_at();

