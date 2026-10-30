# NESTORA — Database Documentation

> Canonical source: `database/schema.sql`  
> Migration baseline: `backend/src/main/resources/db/migration/V1__baseline_schema.sql`  
> Database engine: MySQL 8.0  
> Database name: `nestora`  
> Default character set: `utf8mb4`  
> Default collation: `utf8mb4_unicode_ci`  
> Hibernate DDL mode: `validate`

---

## 1. Schema Management & Safety Policy

1. **Canonical Schema Rule:** The single source of truth for the entire database structure is `database/schema.sql`. Any future schema modification must first be designed and committed to `database/schema.sql`, and then packaged as a separate, incremented Flyway migration script (`V2__description.sql`, `V3__description.sql`, etc.).
2. **Flyway Managed:** All development, staging, and production database instances are evolved strictly via Flyway migrations.
3. **Hibernate Validation:** In `dev` and `prod` profiles, `spring.jpa.hibernate.ddl-auto` is set to `validate`. Hibernate validates that Java entities match the Flyway-applied schema. It is strictly forbidden from executing `update` or `create-drop` in production.
4. **Validation Scope Note:** Hibernate's `validate` mode verifies table existence, column names, column types, and basic nullability. It does **not** validate composite indexes, full-text indexes, foreign key cascade behaviors, check constraints, generated column expressions, or seed records. Those database-level guarantees are established and verified via Flyway scripts and MySQL engine checks.

---

## 2. All 14 Database Tables

### Table 1: `users`
*Represents all system actors (tenants, property owners, and system administrators).*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `BIGINT` | No | AUTO_INCREMENT | Primary Key |
| `name` | `VARCHAR(100)` | No | - | Full name of the user |
| `email` | `VARCHAR(150)` | No | - | Unique login email address |
| `phone` | `VARCHAR(15)` | No | - | Contact phone number |
| `password_hash` | `VARCHAR(100)` | No | - | BCrypt password hash |
| `role` | `ENUM('TENANT','OWNER','ADMIN')` | No | - | User role for authorization |
| `email_verified` | `BOOLEAN` | No | `FALSE` | Email verification status |
| `blocked` | `BOOLEAN` | No | `FALSE` | Administrative block status |
| `created_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | Account creation timestamp |
| `updated_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP ON UPDATE` | Last modification timestamp |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `UNIQUE KEY (email)`

---

### Table 2: `otp_tokens`
*Stores hashed one-time passwords for signup email verification and password reset workflows.*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `BIGINT` | No | AUTO_INCREMENT | Primary Key |
| `email` | `VARCHAR(150)` | No | - | Recipient email address |
| `purpose` | `ENUM('SIGNUP','FORGOT_PASSWORD')` | No | - | Purpose of the OTP |
| `otp_hash` | `VARCHAR(100)` | No | - | Hashed OTP token value |
| `expires_at` | `DATETIME` | No | - | Expiration timestamp (created_at + 10 min) |
| `attempts` | `TINYINT` | No | `0` | Failed verification attempts (max 5) |
| `used` | `BOOLEAN` | No | `FALSE` | Whether token was consumed |
| `created_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | Creation timestamp |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `INDEX idx_otp_email_purpose (email, purpose)`

---

### Table 3: `refresh_tokens`
*Manages active user sessions, refresh token rotation, and reuse detection.*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `BIGINT` | No | AUTO_INCREMENT | Primary Key |
| `user_id` | `BIGINT` | No | - | Foreign Key referencing `users(id)` |
| `token_hash` | `VARCHAR(64)` | No | - | SHA-256 hash of the raw refresh token |
| `device_info` | `VARCHAR(255)` | Yes | `NULL` | Optional client device / user-agent label |
| `expires_at` | `DATETIME` | No | - | Expiration timestamp (created_at + 7 days) |
| `revoked` | `BOOLEAN` | No | `FALSE` | Whether token has been revoked |
| `reuse_detected` | `BOOLEAN` | No | `FALSE` | Flag indicating token compromise |
| `replaced_by` | `VARCHAR(64)` | Yes | `NULL` | Hash of the successor token in rotation chain |
| `created_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | Issuance timestamp |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `UNIQUE KEY (token_hash)`
  - `CONSTRAINT fk_rt_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`
  - `INDEX idx_rt_user (user_id, revoked)`
  - `INDEX idx_rt_hash (token_hash)`

---

### Table 4: `amenities`
*Master lookup table of listing amenities.*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `INT` | No | AUTO_INCREMENT | Primary Key |
| `name` | `VARCHAR(50)` | No | - | Amenity name |
| `icon` | `VARCHAR(50)` | Yes | `NULL` | UI icon identifier |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `UNIQUE KEY (name)`
- **Seed Data:** 14 standard amenities (WiFi, AC, Parking, Attached Bathroom, Geyser, Washing Machine, Refrigerator, TV, Power Backup, Meals Included, Housekeeping, CCTV, Lift, Water Purifier).

---

### Table 5: `listings`
*Core accommodation listing entity.*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `BIGINT` | No | AUTO_INCREMENT | Primary Key |
| `owner_id` | `BIGINT` | No | - | Foreign Key referencing `users(id)` |
| `title` | `VARCHAR(150)` | No | - | Listing title |
| `description` | `TEXT` | Yes | `NULL` | Detailed description |
| `city` | `VARCHAR(80)` | No | - | City name |
| `area` | `VARCHAR(100)` | No | - | Neighborhood / area name |
| `address` | `VARCHAR(255)` | No | - | Full street address |
| `latitude` | `DECIMAL(10,7)` | No | - | GPS latitude |
| `longitude` | `DECIMAL(10,7)` | No | - | GPS longitude |
| `rent` | `DECIMAL(10,2)` | No | - | Monthly rent amount (CHECK rent > 0) |
| `deposit` | `DECIMAL(10,2)` | No | `0.00` | Security deposit (CHECK deposit >= 0) |
| `room_type` | `ENUM(...)` | No | - | Room type categorization |
| `furnishing` | `ENUM(...)` | No | - | Furnishing status |
| `gender_preference` | `ENUM(...)` | No | `'ANY'` | Gender preference |
| `status` | `ENUM(...)` | No | `'PENDING'` | Moderation status |
| `rejection_reason` | `VARCHAR(255)` | Yes | `NULL` | Rejection feedback from admin |
| `avg_rating` | `DECIMAL(2,1)` | No | `0.0` | Denormalized average review rating |
| `review_count` | `INT` | No | `0` | Denormalized review count |
| `created_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | Creation timestamp |
| `updated_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP ON UPDATE` | Last modification timestamp |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `CONSTRAINT fk_listing_owner FOREIGN KEY (owner_id) REFERENCES users(id)`
  - `INDEX idx_listing_status_city (status, city)`
  - `INDEX idx_listing_rent (rent)`
  - `INDEX idx_listing_geo (latitude, longitude)`
  - `INDEX idx_listing_owner (owner_id)`
  - `FULLTEXT INDEX ft_listing_search (title, area, city)`

---

### Table 6: `listing_images`
*Images associated with a listing (1 to 8 images per listing).*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `BIGINT` | No | AUTO_INCREMENT | Primary Key |
| `listing_id` | `BIGINT` | No | - | Foreign Key referencing `listings(id)` |
| `image_url` | `VARCHAR(500)` | No | - | Cloudinary public CDN URL |
| `cloudinary_public_id` | `VARCHAR(200)` | No | - | Cloudinary public ID for deletion |
| `sort_order` | `TINYINT` | No | `0` | Display sorting index |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `CONSTRAINT fk_img_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE`
  - `INDEX idx_img_listing (listing_id)`

---

### Table 7: `listing_amenities`
*Join table mapping listings to amenities (Many-to-Many).*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `listing_id` | `BIGINT` | No | - | Foreign Key referencing `listings(id)` |
| `amenity_id` | `INT` | No | - | Foreign Key referencing `amenities(id)` |

- **Constraints & Indexes:**
  - `PRIMARY KEY (listing_id, amenity_id)`
  - `CONSTRAINT fk_la_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE`
  - `CONSTRAINT fk_la_amenity FOREIGN KEY (amenity_id) REFERENCES amenities(id)`

---

### Table 8: `wishlists`
*Saved properties per user.*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `BIGINT` | No | AUTO_INCREMENT | Primary Key |
| `user_id` | `BIGINT` | No | - | Foreign Key referencing `users(id)` |
| `listing_id` | `BIGINT` | No | - | Foreign Key referencing `listings(id)` |
| `created_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | Creation timestamp |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `UNIQUE KEY uq_wishlist (user_id, listing_id)`
  - `CONSTRAINT fk_wl_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`
  - `CONSTRAINT fk_wl_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE`

---

### Table 9: `visits`
*Scheduled property visits with double-booking prevention.*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `BIGINT` | No | AUTO_INCREMENT | Primary Key |
| `listing_id` | `BIGINT` | No | - | Foreign Key referencing `listings(id)` |
| `tenant_id` | `BIGINT` | No | - | Foreign Key referencing `users(id)` |
| `visit_date` | `DATE` | No | - | Date of scheduled visit |
| `slot` | `ENUM('SLOT_10_12','SLOT_12_14','SLOT_14_16','SLOT_16_18')` | No | - | Time slot window |
| `status` | `ENUM('PENDING','ACCEPTED','REJECTED','CANCELLED')` | No | `'PENDING'` | Booking status |
| `created_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | Creation timestamp |
| `updated_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP ON UPDATE` | Last modification timestamp |
| `slot_lock` | `TINYINT` | Yes | Generated | `1` when PENDING/ACCEPTED, else `NULL` |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `UNIQUE KEY uq_no_double_booking (listing_id, visit_date, slot, slot_lock)`
  - `CONSTRAINT fk_visit_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE`
  - `CONSTRAINT fk_visit_tenant FOREIGN KEY (tenant_id) REFERENCES users(id)`
  - `INDEX idx_visit_tenant (tenant_id, status)`
  - `INDEX idx_visit_listing (listing_id, status)`

---

### Table 10: `reviews`
*Verified tenant ratings and comments.*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `BIGINT` | No | AUTO_INCREMENT | Primary Key |
| `listing_id` | `BIGINT` | No | - | Foreign Key referencing `listings(id)` |
| `tenant_id` | `BIGINT` | No | - | Foreign Key referencing `users(id)` |
| `visit_id` | `BIGINT` | No | - | Foreign Key referencing `visits(id)` (proof of visit) |
| `rating` | `TINYINT` | No | - | Star rating 1 to 5 |
| `comment` | `VARCHAR(1000)` | Yes | `NULL` | Written review text |
| `created_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | Creation timestamp |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `UNIQUE KEY uq_review_once (listing_id, tenant_id)`
  - `CONSTRAINT fk_rev_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE`
  - `CONSTRAINT fk_rev_tenant FOREIGN KEY (tenant_id) REFERENCES users(id)`
  - `CONSTRAINT fk_rev_visit FOREIGN KEY (visit_id) REFERENCES visits(id)`

---

### Table 11: `conversations`
*One-to-one conversation thread per tenant per listing.*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `BIGINT` | No | AUTO_INCREMENT | Primary Key |
| `listing_id` | `BIGINT` | No | - | Foreign Key referencing `listings(id)` |
| `tenant_id` | `BIGINT` | No | - | Foreign Key referencing `users(id)` |
| `owner_id` | `BIGINT` | No | - | Foreign Key referencing `users(id)` |
| `last_message_at` | `TIMESTAMP` | Yes | `NULL` | Timestamp of latest message |
| `created_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | Creation timestamp |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `UNIQUE KEY uq_conversation (listing_id, tenant_id)`
  - `CONSTRAINT fk_conv_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE`
  - `CONSTRAINT fk_conv_tenant FOREIGN KEY (tenant_id) REFERENCES users(id)`
  - `CONSTRAINT fk_conv_owner FOREIGN KEY (owner_id) REFERENCES users(id)`
  - `INDEX idx_conv_tenant (tenant_id, last_message_at)`
  - `INDEX idx_conv_owner (owner_id, last_message_at)`

---

### Table 12: `chat_messages`
*Individual real-time chat messages.*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `BIGINT` | No | AUTO_INCREMENT | Primary Key |
| `conversation_id` | `BIGINT` | No | - | Foreign Key referencing `conversations(id)` |
| `sender_id` | `BIGINT` | No | - | Foreign Key referencing `users(id)` |
| `content` | `VARCHAR(2000)` | No | - | Message body |
| `is_read` | `BOOLEAN` | No | `FALSE` | Read status |
| `created_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | Message timestamp |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `CONSTRAINT fk_msg_conv FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE`
  - `CONSTRAINT fk_msg_sender FOREIGN KEY (sender_id) REFERENCES users(id)`
  - `INDEX idx_msg_history (conversation_id, created_at)`
  - `INDEX idx_msg_unread (conversation_id, is_read, sender_id)`

---

### Table 13: `nearby_places`
*Overpass API query cache for points of interest near listings.*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `BIGINT` | No | AUTO_INCREMENT | Primary Key |
| `listing_id` | `BIGINT` | No | - | Foreign Key referencing `listings(id)` |
| `category` | `ENUM('COLLEGE','HOSPITAL','BUS_STOP','MARKET')` | No | - | POI category |
| `name` | `VARCHAR(200)` | Yes | `NULL` | Name of facility/place |
| `latitude` | `DECIMAL(10,7)` | No | - | GPS latitude |
| `longitude` | `DECIMAL(10,7)` | No | - | GPS longitude |
| `distance_m` | `INT` | No | - | Distance in meters from listing |
| `fetched_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | Cache timestamp |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `CONSTRAINT fk_np_listing FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE`
  - `INDEX idx_np_listing_cat (listing_id, category, distance_m)`

---

### Table 14: `owner_verifications`
*Owner identity and property ownership verification documents.*

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `BIGINT` | No | AUTO_INCREMENT | Primary Key |
| `owner_id` | `BIGINT` | No | - | Foreign Key referencing `users(id)` |
| `id_proof_path` | `VARCHAR(500)` | No | - | Private storage path for ID proof |
| `property_proof_path` | `VARCHAR(500)` | No | - | Private storage path for property proof |
| `status` | `ENUM('PENDING','APPROVED','REJECTED')` | No | `'PENDING'` | Verification status |
| `rejection_reason` | `VARCHAR(255)` | Yes | `NULL` | Admin feedback on rejection |
| `reviewed_by` | `BIGINT` | Yes | `NULL` | Foreign Key referencing `users(id)` (Admin) |
| `reviewed_at` | `DATETIME` | Yes | `NULL` | Review timestamp |
| `submitted_at` | `TIMESTAMP` | No | `CURRENT_TIMESTAMP` | Submission timestamp |

- **Constraints & Indexes:**
  - `PRIMARY KEY (id)`
  - `UNIQUE KEY (owner_id)`
  - `CONSTRAINT fk_ov_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE`
  - `CONSTRAINT fk_ov_reviewer FOREIGN KEY (reviewed_by) REFERENCES users(id)`

---

## 3. ENUM Reference Table

| ENUM Column | Values |
|-------------|--------|
| `users.role` | `TENANT`, `OWNER`, `ADMIN` |
| `otp_tokens.purpose` | `SIGNUP`, `FORGOT_PASSWORD` |
| `listings.room_type` | `SINGLE_ROOM`, `SHARED_ROOM`, `PG`, `HOSTEL`, `ONE_RK`, `ONE_BHK`, `TWO_BHK`, `THREE_BHK` |
| `listings.furnishing` | `FURNISHED`, `SEMI_FURNISHED`, `UNFURNISHED` |
| `listings.gender_preference` | `ANY`, `MALE`, `FEMALE` |
| `listings.status` | `PENDING`, `APPROVED`, `REJECTED`, `REMOVED` |
| `visits.slot` | `SLOT_10_12`, `SLOT_12_14`, `SLOT_14_16`, `SLOT_16_18` |
| `visits.status` | `PENDING`, `ACCEPTED`, `REJECTED`, `CANCELLED` |
| `nearby_places.category` | `COLLEGE`, `HOSPITAL`, `BUS_STOP`, `MARKET` |
| `owner_verifications.status` | `PENDING`, `APPROVED`, `REJECTED` |

---

## 4. Entity Ownership Table

| Entity | Java Package | Primary Repository |
|--------|--------------|-------------------|
| `User` | `com.nestora.user.entity` | `UserRepository` |
| `OtpToken` | `com.nestora.auth.entity` | `OtpTokenRepository` |
| `RefreshToken` | `com.nestora.auth.entity` | `RefreshTokenRepository` |
| `Amenity` | `com.nestora.listing.entity` | `AmenityRepository` |
| `Listing` | `com.nestora.listing.entity` | `ListingRepository` |
| `ListingImage` | `com.nestora.listing.entity` | `ListingImageRepository` |
| `Wishlist` | `com.nestora.wishlist.entity` | `WishlistRepository` |
| `Visit` | `com.nestora.booking.entity` | `VisitRepository` |
| `Review` | `com.nestora.review.entity` | `ReviewRepository` |
| `Conversation` | `com.nestora.chat.entity` | `ConversationRepository` |
| `ChatMessage` | `com.nestora.chat.entity` | `ChatMessageRepository` |
| `NearbyPlace` | `com.nestora.location.entity` | `NearbyPlaceRepository` |
| `OwnerVerification` | `com.nestora.verification.entity` | `OwnerVerificationRepository` |
