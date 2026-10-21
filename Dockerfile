FROM eclipse-temurin:11-jre@sha256:d218907a19a41f9036cf547a0a84a408cfb1bc56aeb2be090ae867563e086458
RUN mkdir -p /app
ADD https://github.com/Pugmatt/BedrockConnect/releases/latest/download/BedrockConnect-1.0-SNAPSHOT.jar /app
WORKDIR /app
EXPOSE 19132/udp
CMD ["java", "-Xms512M", "-Xmx512M", "-jar", "BedrockConnect-1.0-SNAPSHOT.jar", "nodb=true", "custom_servers=/app/custom_servers.json"]
