-- Migration: create favorite_apps table
-- Run this in the Supabase SQL editor for project gbunixrrvpikpqsrnfkp

CREATE TABLE IF NOT EXISTS favorite_apps (
  id          UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     TEXT        NOT NULL,
  app_id      TEXT        NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_favorite_apps_user_app UNIQUE (user_id, app_id)
);

CREATE INDEX IF NOT EXISTS idx_favorite_apps_user_id
  ON favorite_apps (user_id);

-- Enable Row Level Security
ALTER TABLE favorite_apps ENABLE ROW LEVEL SECURITY;

-- The app uses its own Google OAuth (not Supabase Auth), so all
-- database access goes through the anon key.  We allow anon full
-- access and rely on the app-level user_id column for isolation.
CREATE POLICY "anon_full_access" ON favorite_apps
  FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);
