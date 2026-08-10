FROM eclipse-temurin:21-jre-alpine@sha256:3f08b13888f595cc49edabea7250ba69499ba25602b267da591720769400e08c

RUN apk add --no-cache curl \
    && addgroup -S moneysnap \
    && adduser -S -G moneysnap -h /app moneysnap

WORKDIR /app
COPY --chown=moneysnap:moneysnap build/libs/moneysnap-server.jar /app/app.jar

USER moneysnap
EXPOSE 8080 9091

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=6 \
    CMD curl --fail --silent --show-error http://127.0.0.1:9091/actuator/health >/dev/null || exit 1

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
