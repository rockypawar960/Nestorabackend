# NESTORA — Testing, Setup & Verification Guide

This guide covers local development setup, automated test execution, Docker containerization, and verification workflows.

---

## 1. Local Environment Setup
> Detailed in root `README.md`.

## 2. Maven Wrapper and Existing Automated Tests

The repository has five existing test classes with 25 `@Test` methods. `application-test.yml` runs them against H2 in MySQL mode with Flyway disabled and `ddl-auto: create-drop`. This suite covers unit/MockMvc behavior only; it does not validate MySQL 8 migration DDL.

`pom.xml` targets Java 17. Maven Wrapper 3.3.4 is configured for Maven 3.9.12, compatible with Spring Boot 3.3.10 (Java 17+ and Maven 3.6.3+; see [Spring Boot 3.3 system requirements](https://docs.spring.io/spring-boot/3.3/system-requirements.html)).

Run the complete suite on a machine with JDK 17:
```bash
java -version
./mvnw -version
./mvnw clean test
```
On Windows Command Prompt or PowerShell:
```cmd
java -version
mvnw.cmd -version
mvnw.cmd clean test
```
Record Maven Surefire's actual `Tests run`, failures, and errors. Do not mark Phase 0 complete based on an H2 run or an unexecuted command.

**Current v0 run:** `java`, `javac`, `mvn`, Docker, the MySQL client, and PowerShell are unavailable. Consequently, 0 tests were executed; 25 is the discovered method count, not a passing test result. The Unix wrapper passes `sh -n` and is mode `755`; `mvnw.cmd` has CRLF line endings. Windows execution itself was not available.

## 3. Real MySQL 8 + Flyway Verification (Manual, Required)

The `test` profile disables Flyway and uses H2; it cannot verify MySQL-specific V1 DDL. When Docker is unavailable, perform this check against a real MySQL 8 server. Use a fresh disposable schema and a dedicated local database user; never point this procedure at production or an existing data store.

1. Connect to a local MySQL 8 server with an administrative account. The `--password` option prompts without putting the password in shell history:
   ```bash
   mysql --host=127.0.0.1 --port=3306 --user=root --password
   ```
2. In the MySQL prompt, create a new test schema and user. Replace the password placeholder with a random test-only value; do not commit it. Choose a new schema/user name if these already exist; do not drop existing data.
   ```sql
   CREATE DATABASE nestora_phase0_verify CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER 'nestora_phase0_verify'@'127.0.0.1' IDENTIFIED BY 'replace-with-random-test-only-password';
   GRANT ALL PRIVILEGES ON nestora_phase0_verify.* TO 'nestora_phase0_verify'@'127.0.0.1';
   ```
3. In the same local shell, configure the app to use only that test database. The disabled TLS options below are for loopback-only testing; do not reuse this URL in production.
   ```bash
   export SPRING_PROFILES_ACTIVE=dev
   export DB_URL='jdbc:mysql://127.0.0.1:3306/nestora_phase0_verify?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true'
   export DB_USERNAME='nestora_phase0_verify'
   read -r -s -p 'MySQL test password: ' DB_PASSWORD
   printf '\n'
   export DB_PASSWORD
   export JWT_SECRET="$(openssl rand -hex 32)"
   export ADMIN_EMAIL='admin@example.invalid'
   export ADMIN_PASSWORD="$(openssl rand -hex 24)"
   ```
4. Start the app:
   ```bash
   ./mvnw spring-boot:run
   ```
   Confirm Flyway reports V1 success and the application reaches `Started NestoraApplication` without Hibernate schema-validation errors (`ddl-auto: validate`).
5. In a second MySQL session connected to `nestora_phase0_verify`, run:
   ```sql
   SELECT version, success FROM flyway_schema_history WHERE version = '1';
   SELECT COUNT(*) AS application_tables
     FROM information_schema.tables
     WHERE table_schema = DATABASE()
       AND table_type = 'BASE TABLE'
       AND table_name <> 'flyway_schema_history';
   SELECT COUNT(*) AS amenity_count FROM amenities;
   SELECT name, icon FROM amenities ORDER BY id;
   SELECT table_name, constraint_name, column_name, referenced_table_name, referenced_column_name
     FROM information_schema.key_column_usage
     WHERE constraint_schema = DATABASE() AND referenced_table_name IS NOT NULL
     ORDER BY table_name, constraint_name;
   SELECT table_name, index_name, non_unique, column_name
     FROM information_schema.statistics
     WHERE table_schema = DATABASE()
     ORDER BY table_name, index_name, seq_in_index;
   SELECT column_name, extra, generation_expression
     FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = 'visits' AND column_name = 'slot_lock';
   ```
   Expect V1 `success = 1`, 14 application tables (plus Flyway history), 14 amenities, the declared foreign keys/indexes, and `slot_lock` reported as a stored generated column.
6. To exercise the generated column, run these statements in the disposable database; `slot_lock` should be `1`, and the transaction leaves no rows:
   ```sql
   START TRANSACTION;
   INSERT INTO users (name, email, phone, password_hash, role)
     VALUES ('Phase0 Owner', 'phase0-owner@example.invalid', '1111111111', 'not-a-login-hash', 'OWNER');
   SET @owner_id = LAST_INSERT_ID();
   INSERT INTO users (name, email, phone, password_hash, role)
     VALUES ('Phase0 Tenant', 'phase0-tenant@example.invalid', '2222222222', 'not-a-login-hash', 'TENANT');
   SET @tenant_id = LAST_INSERT_ID();
   INSERT INTO listings (owner_id, title, city, area, address, latitude, longitude, rent, room_type, furnishing)
     VALUES (@owner_id, 'Phase0 verification', 'Test City', 'Test Area', '1 Test Street', 0, 0, 1, 'SINGLE_ROOM', 'UNFURNISHED');
   SET @listing_id = LAST_INSERT_ID();
   INSERT INTO visits (listing_id, tenant_id, visit_date, slot, status)
     VALUES (@listing_id, @tenant_id, DATE_ADD(CURRENT_DATE, INTERVAL 1 DAY), 'SLOT_10_12', 'PENDING');
   SELECT slot_lock FROM visits WHERE id = LAST_INSERT_ID();
   ROLLBACK;
   ```

Do not treat H2 as a substitute for this MySQL 8 check. A live MySQL run is still required before Phase 0 can be marked complete.

---

## 4. Phase-by-Phase Verification Log
- **Phase 0:** Verification pending. The five existing test classes (25 methods) were inspected but not executed in this environment. H2 does not validate the V1 MySQL migration; complete Sections 2 and 3 with recorded results before marking Phase 0 complete.
- **Phase 1:** ⏳ Pending
- **Phase 2:** ⏳ Pending
- **Phase 3:** ⏳ Pending
- **Phase 4:** ⏳ Pending
- **Phase 5:** ⏳ Pending
- **Phase 6:** ⏳ Pending
- **Phase 7:** ⏳ Pending
- **Phase 8:** ⏳ Pending
