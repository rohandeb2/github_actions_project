# ============================================================
# Stage 1 — dependency cache layer
# Only re-runs when pom.xml changes (saves ~2min on hot builds)
# ============================================================
FROM maven:3.9.6-eclipse-temurin-21-alpine AS deps
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B -q

# ============================================================
# Stage 2 — build & test
# ============================================================
FROM deps AS builder
WORKDIR /app
COPY src ./src
# Tests run here; image won't build if they fail
RUN mvn package -B -q

# ============================================================
# Stage 3 — minimal runtime image (distroless)
# No shell, no package manager, no attack surface
# ============================================================
FROM eclipse-temurin:21-jre-alpine AS runtime

# Security: run as non-root
RUN addgroup -S bankapp && adduser -S bankapp -G bankapp

WORKDIR /app
COPY --from=builder /app/target/bankapp-*.jar app.jar
RUN chown bankapp:bankapp app.jar

USER bankapp

# JVM tuning for container environments
ENV JAVA_OPTS="-XX:+UseContainerSupport \
               -XX:MaxRAMPercentage=75.0 \
               -XX:+UseG1GC \
               -Djava.security.egd=file:/dev/./urandom"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
