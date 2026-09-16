CREATE TABLE IF NOT EXISTS profiles (
  phone TEXT PRIMARY KEY,
  map_id TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  school TEXT NOT NULL DEFAULT '',
  bio TEXT NOT NULL DEFAULT '',
  tagline TEXT NOT NULL DEFAULT '',
  grade TEXT NOT NULL DEFAULT '',
  city_id TEXT NOT NULL DEFAULT '',
  subjects JSONB NOT NULL DEFAULT '[]'::jsonb,
  mood_emoji TEXT NOT NULL DEFAULT '',
  mood_label TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS friendships (
  id TEXT PRIMARY KEY,
  from_phone TEXT NOT NULL,
  to_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_friendships_from_phone ON friendships (from_phone);
CREATE INDEX IF NOT EXISTS idx_friendships_to_id ON friendships (to_id);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON friendships (status);

-- Prefer accepted, then newest, when collapsing directed or reverse duplicates.
DELETE FROM friendships a
  USING friendships b
 WHERE a.ctid <> b.ctid
   AND LEAST(a.from_phone, a.to_id) = LEAST(b.from_phone, b.to_id)
   AND GREATEST(a.from_phone, a.to_id) = GREATEST(b.from_phone, b.to_id)
   AND (
     (a.status = 'pending' AND b.status = 'accepted')
     OR (a.status = b.status AND a.updated_at < b.updated_at)
     OR (a.status = b.status AND a.updated_at = b.updated_at AND a.ctid < b.ctid)
   );
DROP INDEX IF EXISTS idx_friendships_pair;
CREATE UNIQUE INDEX IF NOT EXISTS idx_friendships_undirected_pair
  ON friendships (LEAST(from_phone, to_id), GREATEST(from_phone, to_id));

CREATE TABLE IF NOT EXISTS profile_views (
  viewer_phone TEXT NOT NULL,
  target_phone TEXT NOT NULL,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (viewer_phone, target_phone)
);

CREATE TABLE IF NOT EXISTS conversations (
  id TEXT PRIMARY KEY,
  participant_a TEXT NOT NULL,
  participant_b TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_message JSONB
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_conversations_pair
  ON conversations (participant_a, participant_b);

CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  from_key TEXT NOT NULL,
  text TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_created
  ON messages (conversation_id, created_at);

CREATE TABLE IF NOT EXISTS conversation_unread (
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  participant_key TEXT NOT NULL,
  unread_count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (conversation_id, participant_key)
);

CREATE TABLE IF NOT EXISTS device_tokens (
  token TEXT PRIMARY KEY,
  phone TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'unknown',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_phone ON device_tokens (phone);

CREATE TABLE IF NOT EXISTS subscriptions (
  id TEXT PRIMARY KEY,
  phone TEXT NOT NULL,
  plan TEXT NOT NULL DEFAULT 'plus',
  status TEXT NOT NULL DEFAULT 'active',
  expires_at TIMESTAMPTZ,
  grades JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS grades JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_subscriptions_phone ON subscriptions (phone);

DELETE FROM subscriptions a
  USING subscriptions b
 WHERE a.ctid < b.ctid
   AND a.phone = b.phone;
CREATE UNIQUE INDEX IF NOT EXISTS idx_subscriptions_phone_unique
  ON subscriptions (phone);

CREATE TABLE IF NOT EXISTS notification_messages (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  phone TEXT,
  phones JSONB NOT NULL DEFAULT '[]'::jsonb,
  topic TEXT,
  audience TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'stored_only',
  success_count INTEGER NOT NULL DEFAULT 0,
  failure_count INTEGER NOT NULL DEFAULT 0,
  error_message TEXT,
  target_count INTEGER NOT NULL DEFAULT 0,
  ok BOOLEAN NOT NULL DEFAULT true,
  detail TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE notification_messages ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE notification_messages ADD COLUMN IF NOT EXISTS phones JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE notification_messages ADD COLUMN IF NOT EXISTS topic TEXT;
ALTER TABLE notification_messages ADD COLUMN IF NOT EXISTS audience TEXT NOT NULL DEFAULT '';
ALTER TABLE notification_messages ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'stored_only';
ALTER TABLE notification_messages ADD COLUMN IF NOT EXISTS success_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE notification_messages ADD COLUMN IF NOT EXISTS failure_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE notification_messages ADD COLUMN IF NOT EXISTS error_message TEXT;
ALTER TABLE notification_messages ADD COLUMN IF NOT EXISTS target_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE notification_messages ADD COLUMN IF NOT EXISTS ok BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE notification_messages ADD COLUMN IF NOT EXISTS detail TEXT NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS app_users (
  phone TEXT PRIMARY KEY,
  display_name TEXT NOT NULL DEFAULT '',
  grade TEXT NOT NULL DEFAULT '',
  birthdate TEXT,
  interests JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL DEFAULT 'active',
  onboarding_complete BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_users_created_at ON app_users (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_users_status ON app_users (status);

-- Archive of accounts removed via Delete account (re-register creates a fresh app_users row).
CREATE TABLE IF NOT EXISTS deleted_users (
  id BIGSERIAL PRIMARY KEY,
  phone TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  grade TEXT NOT NULL DEFAULT '',
  birthdate TEXT,
  interests JSONB NOT NULL DEFAULT '[]'::jsonb,
  plan TEXT NOT NULL DEFAULT 'free',
  onboarding_complete BOOLEAN NOT NULL DEFAULT FALSE,
  registered_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_deleted_users_deleted_at ON deleted_users (deleted_at DESC);
CREATE INDEX IF NOT EXISTS idx_deleted_users_phone ON deleted_users (phone);

-- Shared grade leaderboard (one row per active student phone).
CREATE TABLE IF NOT EXISTS leaderboard_scores (
  phone TEXT PRIMARY KEY,
  display_name TEXT NOT NULL DEFAULT '',
  grade TEXT NOT NULL DEFAULT '',
  points INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_leaderboard_scores_grade_points
  ON leaderboard_scores (grade, points DESC);

-- Daily free AI usage caps (tutor / wrong_answer / explain).
CREATE TABLE IF NOT EXISTS ai_usage (
  phone TEXT NOT NULL,
  day DATE NOT NULL,
  feature TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (phone, day, feature)
);

CREATE TABLE IF NOT EXISTS payments (
  id TEXT PRIMARY KEY,
  phone TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  method TEXT NOT NULL DEFAULT 'CBE',
  amount INTEGER NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'ETB',
  plan TEXT NOT NULL DEFAULT 'plus',
  grades JSONB NOT NULL DEFAULT '[]'::jsonb,
  billing_period TEXT NOT NULL DEFAULT 'monthly',
  reference TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'verified', 'rejected')),
  receipt_path TEXT,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payments_status_created
  ON payments (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_phone_created
  ON payments (phone, created_at DESC);
