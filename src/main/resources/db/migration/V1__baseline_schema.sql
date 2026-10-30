-- =====================================================
-- Nestora - V1 Baseline Schema
-- Derived from database/schema.sql (canonical source)
-- Flyway migration baseline
-- =====================================================

-- -----------------------------------------------------
-- 1. users  (Admin is seeded from Spring code, not here)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  name            VARCHAR(100) NOT NULL,
  email           VARCHAR(150) NOT NULL UNIQUE,
  phone           VARCHAR(15)  NOT NULL,
  password_hash   VARCHAR(100) NOT NULL,
  role            ENUM('TENANT','OWNER','ADMIN') NOT NULL,
  email_verified  BOOLEAN NOT NULL DEFAULT FALSE,
  blocked         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 2. otp_tokens  (OTP is stored hashed)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS otp_tokens (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  email       VARCHAR(150) NOT NULL,
  purpose     ENUM('SIGNUP','FORGOT_PASSWORD') NOT NULL,
  otp_hash    VARCHAR(100) NOT NULL,
  expires_at  DATETIME NOT NULL,                 -- created_at + 10 min
  attempts    TINYINT NOT NULL DEFAULT 0,        -- max 5 (checked in service)
  used        BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_otp_email_purpose (email, purpose)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 3. refresh_tokens  (multi-device, hashed, rotated)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id              BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id         BIGINT NOT NULL,
  token_hash      VARCHAR(64) NOT NULL UNIQUE,      -- SHA-256 hex of raw token
  device_info     VARCHAR(255) NULL,                -- optional User-Agent or device label
  expires_at      DATETIME NOT NULL,
  revoked         BOOLEAN NOT NULL DEFAULT FALSE,
  reuse_detected  BOOLEAN NOT NULL DEFAULT FALSE,   -- TRUE = token family compromised
  replaced_by     VARCHAR(64) NULL,                 -- hash of successor token (rotation chain)
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_rt_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_rt_user (user_id, revoked),
  INDEX idx_rt_hash (token_hash)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 4. amenities (fixed master list)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS amenities (
  id    INT AUTO_INCREMENT PRIMARY KEY,
  name  VARCHAR(50) NOT NULL UNIQUE,
  icon  VARCHAR(50) NULL
) ENGINE=InnoDB;

INSERT INTO amenities (name, icon) VALUES
 ('WiFi','wifi'), ('AC','ac'), ('Parking','parking'), ('Attached Bathroom','bath'),
 ('Geyser','geyser'), ('Washing Machine','washer'), ('Refrigerator','fridge'),
 ('TV','tv'), ('Power Backup','power'), ('Meals Included','meals'),
 ('Housekeeping','clean'), ('CCTV','cctv'), ('Lift','lift'), ('Water Purifier','water')
 ON DUPLICATE KEY UPDATE name=VALUES(name);

-- -----------------------------------------------------
-- 5. listings
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS listings (
  id                 BIGINT AUTO_INCREMENT PRIMARY KEY,
  owner_id           BIGINT NOT NULL,
  title              VARCHAR(150) NOT NULL,
  description        TEXT,
  city               VARCHAR(80)  NOT NULL,
  area               VARCHAR(100) NOT NULL,
  address            VARCHAR(255) NOT NULL,
  latitude           DECIMAL(10,7) NOT NULL,
  longitude          DECIMAL(10,7) NOT NULL,
  rent               DECIMAL(10,2) NOT NULL CHECK (rent > 0),
  deposit            DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (deposit >= 0),
  room_type          ENUM('SINGLE_ROOM','SHARED_ROOM','PG','HOSTEL','ONE_RK','ONE_BHK','TWO_BHK','THREE_BHK') NOT NULL,
  furnishing         ENUM('FURNISHED','SEMI_FURNISHED','UNFURNISHED') NOT NULL,
  gender_preference  ENUM('ANY','MALE','FEMALE') NOT NULL DEFAULT 'ANY',
  status             ENUM('PENDING','APPROVED','REJECTED','REMOVED') NOT NULL DEFAULT 'PENDING',
  rejection_reason   VARCHAR(255) NULL,
  avg_rating         DECIMAL(2,1) NOT NULL DEFAULT 0.0,   -- denormalised for sorting
  review_count       INT NOT NULL DEFAULT 0,
  created_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_listing_owner FOREIGN KEY (owner_id) REFERENCES users(id),
  INDEX idx_listing_status_city (status, city),
  INDEX idx_listing_rent (rent),
  INDEX idx_listing_geo (latitude, longitude),     -- bounding-box filter before Haversine
  INDEX idx_listing_owner (owner_id),
  FULLTEXT INDEX ft_listing_search (title, area, city)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 6. listing_images  (1-8 per listing, enforced in service)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS listing_images (
  id                 BIGINT AUTO_INCREMENT PRIMARY KEY,
  listing_id         BIGINT NOT NULL,
  image_url          VARCHAR(500) NOT NULL,
  cloudinary_public_id VARCHAR(200) NOT NULL,      -- needed to delete from Cloudinary
  sort_order         TINYINT NOT NULL DEFAULT 0,
  CONSTRAINT fk_img_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE,
  INDEX idx_img_listing (listing_id)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 7. listing_amenities (many-to-many)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS listing_amenities (
  listing_id  BIGINT NOT NULL,
  amenity_id  INT NOT NULL,
  PRIMARY KEY (listing_id, amenity_id),
  CONSTRAINT fk_la_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE,
  CONSTRAINT fk_la_amenity FOREIGN KEY (amenity_id) REFERENCES amenities(id)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 8. wishlists
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS wishlists (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id     BIGINT NOT NULL,
  listing_id  BIGINT NOT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_wishlist (user_id, listing_id),
  CONSTRAINT fk_wl_user    FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
  CONSTRAINT fk_wl_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 9. visits (fixed slots, no double-booking)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS visits (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  listing_id  BIGINT NOT NULL,
  tenant_id   BIGINT NOT NULL,
  visit_date  DATE NOT NULL,
  slot        ENUM('SLOT_10_12','SLOT_12_14','SLOT_14_16','SLOT_16_18') NOT NULL,
  status      ENUM('PENDING','ACCEPTED','REJECTED','CANCELLED') NOT NULL DEFAULT 'PENDING',
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- 1 while the slot is held (PENDING/ACCEPTED), NULL once rejected/cancelled.
  -- NULLs are not equal in a UNIQUE index, so freed slots can be rebooked.
  slot_lock   TINYINT AS (IF(status IN ('PENDING','ACCEPTED'), 1, NULL)) STORED,
  UNIQUE KEY uq_no_double_booking (listing_id, visit_date, slot, slot_lock),
  CONSTRAINT fk_visit_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE,
  CONSTRAINT fk_visit_tenant  FOREIGN KEY (tenant_id)  REFERENCES users(id),
  INDEX idx_visit_tenant (tenant_id, status),
  INDEX idx_visit_listing (listing_id, status)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 10. reviews (one per tenant per listing)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS reviews (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  listing_id  BIGINT NOT NULL,
  tenant_id   BIGINT NOT NULL,
  visit_id    BIGINT NOT NULL,                     -- proof of accepted + past visit
  rating      TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     VARCHAR(1000),
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_review_once (listing_id, tenant_id),
  CONSTRAINT fk_rev_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE,
  CONSTRAINT fk_rev_tenant  FOREIGN KEY (tenant_id)  REFERENCES users(id),
  CONSTRAINT fk_rev_visit   FOREIGN KEY (visit_id)   REFERENCES visits(id)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 11. conversations (one per tenant per listing)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS conversations (
  id               BIGINT AUTO_INCREMENT PRIMARY KEY,
  listing_id       BIGINT NOT NULL,
  tenant_id        BIGINT NOT NULL,
  owner_id         BIGINT NOT NULL,
  last_message_at  TIMESTAMP NULL,
  created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_conversation (listing_id, tenant_id),
  CONSTRAINT fk_conv_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE,
  CONSTRAINT fk_conv_tenant  FOREIGN KEY (tenant_id)  REFERENCES users(id),
  CONSTRAINT fk_conv_owner   FOREIGN KEY (owner_id)   REFERENCES users(id),
  INDEX idx_conv_tenant (tenant_id, last_message_at),
  INDEX idx_conv_owner  (owner_id,  last_message_at)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 12. chat_messages
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS chat_messages (
  id               BIGINT AUTO_INCREMENT PRIMARY KEY,
  conversation_id  BIGINT NOT NULL,
  sender_id        BIGINT NOT NULL,
  content          VARCHAR(2000) NOT NULL,
  is_read          BOOLEAN NOT NULL DEFAULT FALSE,
  created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_msg_conv   FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
  CONSTRAINT fk_msg_sender FOREIGN KEY (sender_id)       REFERENCES users(id),
  INDEX idx_msg_history (conversation_id, created_at),
  INDEX idx_msg_unread  (conversation_id, is_read, sender_id)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 13. nearby_places (Overpass API cache)
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS nearby_places (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  listing_id  BIGINT NOT NULL,
  category    ENUM('COLLEGE','HOSPITAL','BUS_STOP','MARKET') NOT NULL,
  name        VARCHAR(200),
  latitude    DECIMAL(10,7) NOT NULL,
  longitude   DECIMAL(10,7) NOT NULL,
  distance_m  INT NOT NULL,
  fetched_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,  -- refresh if too old
  CONSTRAINT fk_np_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE,
  INDEX idx_np_listing_cat (listing_id, category, distance_m)
) ENGINE=InnoDB;

-- -----------------------------------------------------
-- 14. owner_verifications (once per owner)
--     Files are stored privately; only the path/key is kept here.
--     "Verified" badge = status = 'APPROVED'
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS owner_verifications (
  id                   BIGINT AUTO_INCREMENT PRIMARY KEY,
  owner_id             BIGINT NOT NULL UNIQUE,
  id_proof_path        VARCHAR(500) NOT NULL,
  property_proof_path  VARCHAR(500) NOT NULL,
  status               ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
  rejection_reason     VARCHAR(255) NULL,
  reviewed_by          BIGINT NULL,
  reviewed_at          DATETIME NULL,
  submitted_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_ov_owner    FOREIGN KEY (owner_id)    REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_ov_reviewer FOREIGN KEY (reviewed_by) REFERENCES users(id)
) ENGINE=InnoDB;
