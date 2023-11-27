# Build jar
FROM --platform=$BUILDPLATFORM azul/zulu-openjdk:17 as builder
ARG GRADLE_USER_HOME=.gradle
WORKDIR /build
COPY gradle gradle
COPY gradlew settings.gradle ./
RUN sh gradlew wrapper -i
COPY *.gradle ./
RUN sh gradlew dependencies -i
COPY . .
RUN sh gradlew build -i

# GoLang App Builder
FROM --platform=$BUILDPLATFORM golang:1.20 as go-builder
ARG TARGETOS
ARG TARGETARCH
ARG GATEWAY_PATH=gateway
WORKDIR /build
COPY $GATEWAY_PATH/go.mod $GATEWAY_PATH/go.sum ./
RUN go mod download && go mod verify
COPY $GATEWAY_PATH/ ./
RUN env GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0 go build -v -o /build_output/grpc_gateway ./
RUN ls -lha /build_output

# Service Image
FROM --platform=$BUILDPLATFORM azul/zulu-openjdk:17
ARG GATEWAY_PATH=gateway
ARG SWAGGER_JSON=guildService.swagger.json

RUN apt-get update && \
    apt-get install -y supervisor procps --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*
COPY supervisord.conf /etc/supervisor/supervisord.conf

WORKDIR /app
COPY jars/aws-opentelemetry-agent.jar aws-opentelemetry-agent.jar
COPY --from=builder /build/target/*.jar app.jar
COPY --from=go-builder /build_output/grpc_gateway ./
COPY $GATEWAY_PATH/$SWAGGER_JSON ./apidocs/
COPY $GATEWAY_PATH/third_party ./third_party
RUN chmod +x /app/grpc_gateway
RUN chmod +x /app/app.jar

# Plugin arch gRPC server port
EXPOSE 6565
# Prometheus /metrics web server port
EXPOSE 8080
# gRPC gateway Http port
EXPOSE 8000
ENTRYPOINT ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]