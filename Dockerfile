# Stage 1: build
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN ./mvnw dependency:go-offline -q
COPY src ./src
RUN ./mvnw package -DskipTests -q

# Stage 2: runtime
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
RUN addgroup -S nestora && adduser -S nestora -G nestora
COPY --from=builder /app/target/nestora-backend-*.jar app.jar
USER nestora
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
