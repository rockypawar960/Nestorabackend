# NESTORA — Testing, Setup & Verification Guide

This guide covers local development setup, automated test execution, Docker containerization, and verification workflows.

---

## 1. Local Environment Setup
> Detailed in root `README.md`.

## 2. Running Automated Tests
- Unit and MockMvc slice tests run against an in-memory H2 database using profile `test`:
  ```bash
  ./mvnw clean test
  ```
- All tests execute with zero external service dependencies.

## 3. MySQL 8 Migration Verification (Docker Compose)
To verify Flyway migrations against an authentic MySQL 8 instance:
1. Ensure Docker daemon is active.
2. Launch the MySQL container:
   ```bash
   docker compose up -d mysql
   ```
3. Wait until the health check passes (`docker compose ps` shows `healthy`).
4. Run the backend or run Flyway migrate against the container:
   ```bash
   ./mvnw compile spring-boot:run -Dspring-boot.run.profiles=dev
   ```
5. Confirm all 14 tables are initialized:
   ```bash
   docker exec -it nestora-mysql mysql -uroot -p<DB_ROOT_PASSWORD> -e "USE nestora; SHOW TABLES;"
   ```
6. Expected output: Exactly 14 tables listed, plus `flyway_schema_history`.

---

## 4. Phase-by-Phase Verification Log
- **Phase 0:** Automated H2 tests passing; 14-table DDL baseline validated; response wrappers & exception handling confirmed.
- **Phase 1:** ⏳ Pending
- **Phase 2:** ⏳ Pending
- **Phase 3:** ⏳ Pending
- **Phase 4:** ⏳ Pending
- **Phase 5:** ⏳ Pending
- **Phase 6:** ⏳ Pending
- **Phase 7:** ⏳ Pending
- **Phase 8:** ⏳ Pending
