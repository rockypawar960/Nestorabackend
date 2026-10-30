# Nestora Backend

Nestora is a comprehensive room, PG, and accommodation discovery platform connecting tenants with property owners, supporting visit scheduling, map-based radius search, real-time messaging, and review moderation.

The canonical database schema is located at `database/schema.sql`.

---

## 1. Project Overview

Nestora provides a clean, production-grade Spring Boot 3 REST API backend backed by MySQL 8, secured with JWT and Spring Security, with real-time STOMP WebSockets and automated Flyway database migrations.

---

## 2. Technology Stack

- **Java:** 17 LTS (Eclipse Temurin)
- **Framework:** Spring Boot 3.3.10
- **Database:** MySQL 8.0 (Flyway migrations)
- **Security:** Spring Security 6 + JJWT 0.12.5 (HMAC-SHA256)
- **Persistence:** Spring Data JPA / Hibernate 6 (`ddl-auto: validate`)
- **API Documentation:** springdoc-openapi 2.5.0 / Swagger UI
- **Testing:** JUnit 5, Mockito, MockMvc, AssertJ, H2 (test profile)
- **Containers:** Docker & Docker Compose

---

## 3. Prerequisites

- Java Development Kit (JDK) 17+ installed and available on PATH
- Docker & Docker Compose (optional for containerized deployment)
- Local MySQL 8 instance (if running outside Docker)

---

## 4. Quick Start with Docker Compose

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Configure required environment variables in `.env` (`DB_ROOT_PASSWORD`, `DB_PASSWORD`, `JWT_SECRET`, etc.).
3. Build and launch services:
   ```bash
   docker compose up -d --build
   ```
4. Verify backend health:
   ```bash
   curl http://localhost:8080/actuator/health
   ```

---

## 5. Running from IDE (Local MySQL)

1. Ensure MySQL 8 is running locally on port 3306.
2. Create the `nestora` database:
   ```sql
   CREATE DATABASE nestora CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```
3. Set required environment variables in your IDE run configuration (e.g. `JWT_SECRET`, `DB_PASSWORD`).
4. Run `com.nestora.NestoraApplication` with profile `dev`. Flyway will automatically execute `V1__baseline_schema.sql` to initialize all 14 tables.

`database/schema.sql` is the canonical 14-table schema for review and future changes. For Flyway-managed databases, let Flyway apply the migrations; do not manually execute the canonical script. V1 remains the immutable baseline. Future schema changes must update the canonical schema and ship as new Flyway migrations (V2, V3, etc.). Intentional differences between the standalone schema and V1 are documented in `docs/DATABASE_DOCUMENTATION.md`.

---

## 6. Environment Variables

All secrets and environment-specific settings are supplied via environment variables. See `.env.example` for the complete list and documentation of each variable.

---

## 7. API Documentation

Swagger UI is available at:
```
http://localhost:8080/swagger-ui.html
```
OpenAPI JSON endpoint:
```
http://localhost:8080/v3/api-docs
```
*Note: Feature endpoints will appear in Swagger UI as each corresponding phase is implemented.*

---

## 8. Running Tests

Run the test suite using Maven Wrapper:
```bash
./mvnw clean test
```
On Windows:
```cmd
mvnw.cmd clean test
```
*Note: Tests run against an in-memory H2 database with the `test` profile (`application-test.yml`) and do not require a running MySQL server.*

---

## 9. Project Structure

```
com.nestora
├── NestoraApplication.java
├── auth/           # Authentication, OTP, Token lifecycle (Phase 1)
├── user/           # User aggregate and role management (Phase 1)
├── listing/        # Listing CRUD, images, amenities (Phase 2)
├── wishlist/       # Tenant wishlist management (Phase 3)
├── booking/        # Visit requests and fixed-slot scheduling (Phase 6)
├── review/         # Property reviews and rating computation (Phase 6)
├── chat/           # Real-time WebSocket chat and history (Phase 7)
├── admin/          # Moderation, statistics, admin operations (Phase 5)
├── verification/   # Owner verification document handling (Phase 5)
├── location/       # Geocoding, Haversine, Overpass integration (Phase 4)
├── notification/   # Email notifications via SMTP (Phase 1 & 6)
├── config/         # Security, CORS, Swagger, WebClient configurations
├── security/       # JWT service, authentication filter, interceptors
├── common/         # Standard response wrappers, constants, utilities
└── exception/      # GlobalExceptionHandler and custom exceptions
```

---

## 10. Phase Status

| Phase | Description | Status |
|-------|-------------|--------|
| **Phase 0** | Project Foundation, Architecture, DB Baseline, Security Skeleton, Tests | ✅ Complete |
| **Phase 1** | Authentication & User Management (JWT, Refresh Token, OTP, Admin Seed) | 🔜 Pending |
| **Phase 2** | Listing Management (CRUD, Cloudinary Images, Amenities) | 🔜 Pending |
| **Phase 3** | Search, Filters, Listing Details & Wishlist | 🔜 Pending |
| **Phase 4** | Map & Nearby Places (Nominatim Geocoding, Overpass Cache) | 🔜 Pending |
| **Phase 5** | Admin Moderation & Owner Document Verification | 🔜 Pending |
| **Phase 6** | Visit Scheduling, Slot Locking & Verified Reviews | 🔜 Pending |
| **Phase 7** | Real-Time Chat (WebSocket + STOMP Messaging) | 🔜 Pending |
| **Phase 8** | Final Integration, Security Audit, Verification & Handoff | 🔜 Pending |
