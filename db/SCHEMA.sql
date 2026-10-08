-- =====================================================================
-- Capstone Marketplace — SCHEMA.sql
-- Source of truth for every table, column, type, constraint, and index.
-- Anything not in this file does not exist in the app (Phase 1 SPEC.md).
--
-- Engine: SQLite 3. SQLite has NO row-level security; access control is
-- enforced in SECURITY_RULES.md + API-layer guards. WAL mode for concurrency.
-- =====================================================================

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------
-- users
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT NOT NULL CHECK (length(name) BETWEEN 2 AND 80),
  email         TEXT NOT NULL UNIQUE COLLATE NOCASE
                CHECK (length(email) BETWEEN 5 AND 254),
  password_hash TEXT NOT NULL CHECK (length(password_hash) <= 255),
  role          TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin')),
  is_suspended  INTEGER NOT NULL DEFAULT 0 CHECK (is_suspended IN (0,1)),
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ---------------------------------------------------------------------
-- categories — fixed enum, seeded; NOT user-editable
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  slug  TEXT NOT NULL UNIQUE CHECK (length(slug) BETWEEN 1 AND 40),
  label TEXT NOT NULL CHECK (length(label) BETWEEN 1 AND 80)
);

-- ---------------------------------------------------------------------
-- listings
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS listings (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  seller_id     INTEGER NOT NULL REFERENCES users(id),
  category_id   INTEGER NOT NULL REFERENCES categories(id),
  title         TEXT NOT NULL CHECK (length(title) BETWEEN 3 AND 120),
  description   TEXT NOT NULL CHECK (length(description) BETWEEN 20 AND 5000),
  price         REAL CHECK (price IS NULL OR price >= 0),
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','approved','rejected','sold','deleted')),
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at    TEXT NOT NULL DEFAULT (datetime('now')),
  approved_at   TEXT,
  approved_by   INTEGER REFERENCES users(id)
);

-- ---------------------------------------------------------------------
-- listing_tags — normalized free-form tags
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS listing_tags (
  listing_id INTEGER NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  tag        TEXT NOT NULL CHECK (length(tag) BETWEEN 1 AND 30),
  PRIMARY KEY (listing_id, tag)
);

-- ---------------------------------------------------------------------
-- listing_images — dedicated system screenshots uploaded by sellers
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS listing_images (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  listing_id INTEGER NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  image_url  TEXT NOT NULL,
  caption    TEXT CHECK (caption IS NULL OR length(caption) <= 200),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_listing_images_listing ON listing_images(listing_id, sort_order ASC);

-- ---------------------------------------------------------------------
-- inquiries — buyer -> seller purchase requests
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inquiries (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  listing_id   INTEGER NOT NULL REFERENCES listings(id),
  buyer_id     INTEGER NOT NULL REFERENCES users(id),
  message      TEXT NOT NULL CHECK (length(message) BETWEEN 1 AND 2000),
  status       TEXT NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','responded')),
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at   TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (listing_id, buyer_id)          -- one inquiry per buyer per listing
);

-- ---------------------------------------------------------------------
-- reviews — open reviews, one per (user, listing)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reviews (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  listing_id INTEGER NOT NULL REFERENCES listings(id),
  author_id  INTEGER NOT NULL REFERENCES users(id),
  rating     INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    TEXT NOT NULL CHECK (length(comment) BETWEEN 1 AND 2000),
  is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0,1)),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (listing_id, author_id)
);

-- ---------------------------------------------------------------------
-- review_flags — users flag reviews; admins inspect and delete
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS review_flags (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  review_id  INTEGER NOT NULL REFERENCES reviews(id),
  flagger_id INTEGER NOT NULL REFERENCES users(id),
  reason     TEXT NOT NULL CHECK (length(reason) BETWEEN 1 AND 500),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (review_id, flagger_id)
);

-- ---------------------------------------------------------------------
-- follows — user → person they follow
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS follows (
  follower_id  INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  following_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (follower_id, following_id),
  CHECK (follower_id != following_id)
);

-- ---------------------------------------------------------------------
-- bookmarks — saved listings
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bookmarks (
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  listing_id INTEGER NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, listing_id)
);

-- ---------------------------------------------------------------------
-- notifications — activity events per user
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id     INTEGER NOT NULL REFERENCES users(id),
  type        TEXT NOT NULL CHECK (type IN ('inquiry_received', 'inquiry_responded', 'review', 'follow', 'bookmark_mention')),
  actor_id    INTEGER NOT NULL REFERENCES users(id),  -- who triggered it
  entity_type TEXT,       -- 'listing' | 'review' | 'user'
  entity_id   INTEGER,    -- related item id
  is_read     INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0,1)),
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_notifications_user   ON notifications(user_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_actor  ON notifications(actor_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower     ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following    ON follows(following_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_listing    ON bookmarks(listing_id);

-- ---------------------------------------------------------------------
-- Seed data (idempotent; safe to re-run)
-- ---------------------------------------------------------------------
INSERT OR IGNORE INTO categories (slug, label) VALUES
  ('web-app',        'Web App'),
  ('mobile-app',     'Mobile App'),
  ('ml-ai',          'ML / AI'),
  ('game',           'Game'),
  ('iot-embedded',   'IoT / Embedded'),
  ('data-analysis',  'Data Analysis'),
  ('other',          'Other');
