# NESTORA — Testing, Setup & Verification Guide

This guide covers local development setup, automated test execution, Docker containerization, and verification workflows.

---

## 1. Local Environment Setup
> Detailed in root `README.md`.

## 2. Maven Wrapper and Existing Automated Tests

The repository has five existing test classes with 25 `@Test` methods. `application-test.yml` runs them against H2 in MySQL mode with Flyway disabled and `ddl-auto: create-drop`. This suite covers unit/MockMvc behavior only; it does not validate MySQL 8 migration DDL.

`pom.xml` targets Java 17. Maven Wrapper 3.3.4 is configured for Maven 3.9.12, compatible with Spring Boot 3.3.10 (Java 17+ and Maven 3.6.3+; see [Spring Boot 3.3 system requirements](https://docs.spring.io/spring-boot/3.3/system-requirements.html)).

Run the complete suite from Windows PowerShell with JDK 17 on `PATH`:
```powershell
java -version
.\mvnw.cmd -version
.\mvnw.cmd clean test
```
Record Maven Surefire's actual `Tests run`, failures, and errors. Do not mark Phase 0 complete based on an H2 run or an unexecuted command.

**Current v0 run:** Java, `javac`, Maven, Docker, MySQL, and PowerShell are unavailable. Therefore, 0 tests were executed and no compilation result is available. The 25 methods are a source inventory, not a passing test result. The Unix wrapper passes `sh -n` and is mode `755`; `mvnw.cmd` has CRLF line endings, but Windows execution itself was not available.

## 3. Real MySQL 8 + Flyway Verification (Windows PowerShell + Docker)

The `test` profile disables Flyway and uses H2; it cannot verify MySQL-specific V1 DDL. The following commands start an isolated, disposable MySQL 8 container, bound to localhost port 3307. They do not use or delete the project's Compose volume or any existing database. Run from the repository root in Windows PowerShell, and stop only the temporary container created below.

1. Generate local-only passwords and start a fresh MySQL 8 container:
   ```powershell
   function New-RandomSecret {
       $bytes = New-Object byte[] 32
       $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
       try {
           $rng.GetBytes($bytes)
           [Convert]::ToBase64String($bytes)
       }
       finally {
           $rng.Dispose()
       }
   }

   $env:MYSQL_ROOT_PASSWORD = New-RandomSecret
   $env:MYSQL_PASSWORD = New-RandomSecret
   $env:JWT_SECRET = New-RandomSecret
   $env:ADMIN_PASSWORD = New-RandomSecret
   $env:MYSQL_DATABASE = 'nestora_phase0_verify'
   $env:MYSQL_USER = 'nestora_phase0_verify'

   docker run --detach --rm --name nestora-phase0-mysql `
       --publish 127.0.0.1:3307:3306 `
       --env MYSQL_ROOT_PASSWORD `
       --env MYSQL_DATABASE `
       --env MYSQL_USER `
       --env MYSQL_PASSWORD `
       mysql:8.0
   if ($LASTEXITCODE -ne 0) { throw 'Could not start the disposable MySQL 8 container.' }

   $mysqlReady = $false
   for ($attempt = 0; $attempt -lt 60 -and -not $mysqlReady; $attempt++) {
       $logs = docker logs nestora-phase0-mysql 2>&1
       $mysqlReady = [bool]($logs -match 'ready for connections')
       if (-not $mysqlReady) { Start-Sleep -Seconds 2 }
   }
   if (-not $mysqlReady) { docker logs nestora-phase0-mysql; throw 'MySQL 8 did not become ready.' }
   ```
2. Point the app at the disposable database and start it. The disabled TLS options are only for this loopback test; do not reuse this URL in production.
   ```powershell
   $env:SPRING_PROFILES_ACTIVE = 'dev'
   $env:DB_URL = 'jdbc:mysql://127.0.0.1:3307/nestora_phase0_verify?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true'
   $env:DB_USERNAME = $env:MYSQL_USER
   $env:DB_PASSWORD = $env:MYSQL_PASSWORD
   $env:ADMIN_EMAIL = 'phase0-admin@example.invalid'
   .\mvnw.cmd spring-boot:run
   ```
   Confirm Flyway reports V1 success and the app reaches `Started NestoraApplication` without Hibernate schema-validation errors (`ddl-auto: validate`). Stop the app with Ctrl+C after startup.
3. Connect to the disposable database. Enter the generated MySQL password when prompted:
   ```powershell
   docker exec -it nestora-phase0-mysql mysql --user=nestora_phase0_verify --password nestora_phase0_verify
   ```
   Run these checks in the MySQL prompt:
   ```sql
   SELECT version, success FROM flyway_schema_history WHERE version = '1';
   SELECT COUNT(*) AS application_tables
     FROM information_schema.tables
     WHERE table_schema = DATABASE()
       AND table_type = 'BASE TABLE'
       AND table_name <> 'flyway_schema_history';
   SELECT COUNT(*) AS amenity_count FROM amenities;
   SELECT name, icon FROM amenities ORDER BY id;
   SELECT COUNT(*) AS foreign_key_count
     FROM information_schema.table_constraints
     WHERE constraint_schema = DATABASE() AND constraint_type = 'FOREIGN KEY';
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
   Expect V1 `success = 1`, 14 application tables (plus Flyway history), 14 amenities, 20 foreign keys, and `slot_lock` reported as a stored generated column. Compare the returned index list with the V1 DDL.
4. Exercise `slot_lock` in a transaction. The generated value should be `1`; the transaction leaves no rows:
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
   Optionally repeat the same visit insert before `ROLLBACK`; it should fail with a duplicate-key error due to `uq_no_double_booking`.
5. Stop the disposable container. Because it was started with `--rm` and no named volume, this removes only the temporary database:
   ```powershell
   docker stop nestora-phase0-mysql
   ```

Do not treat H2 as a substitute for this MySQL 8 check. The MySQL migration and Hibernate validation remain pending until these steps are actually run and their output is recorded.

---

## 4. Phase-by-Phase Verification Log
- **Phase 0:** Verification pending. Approved implementation work is present, but the five existing test classes (25 methods) were not executed and the real MySQL 8 migration was not run in this environment. Java, Maven, Docker, and MySQL are unavailable here; no compilation, test, or migration pass is claimed. Run Sections 2 and 3 in Windows PowerShell and record the actual output before marking Phase 0 complete.
- **Phase 1:** ⏳ Pending
- **Phase 2:** ⏳ Pending
- **Phase 3:** ⏳ Pending
- **Phase 4:** ⏳ Pending
- **Phase 5:** ⏳ Pending
- **Phase 6:** ⏳ Pending
- **Phase 7:** ⏳ Pending
- **Phase 8:** ⏳ Pending
