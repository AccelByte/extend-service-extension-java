# gRPC server builder
FROM --platform=$BUILDPLATFORM ibm-semeru-runtimes:open-17-jdk as grpc-server-builder
WORKDIR /build
COPY gradle gradle
COPY gradlew settings.gradle .
RUN sh gradlew wrapper -i
COPY *.gradle .
RUN sh gradlew dependencies -i
COPY . .
RUN sh gradlew build -i


# gRPC gateway builder
FROM --platform=$BUILDPLATFORM golang:1.20 as grpc-gateway-builder
ARG TARGETOS
ARG TARGETARCH
ARG GOOS=$TARGETOS
ARG GOARCH=$TARGETARCH
ARG CGO_ENABLED=0
WORKDIR /build
COPY gateway/go.mod gateway/go.sum .
RUN go mod download && \
    go mod verify
COPY gateway/ .
RUN go build -v -o /output/$TARGETOS/$TARGETARCH/grpc_gateway .


# Extend Service Extension app
FROM ibm-semeru-runtimes:open-17-jre
ARG TARGETOS
ARG TARGETARCH
WORKDIR /app
COPY --from=grpc-server-builder /build/target/*.jar app.jar
COPY jars/aws-opentelemetry-agent.jar aws-opentelemetry-agent.jar
COPY --from=grpc-gateway-builder /output/$TARGETOS/$TARGETARCH/grpc_gateway .
COPY gateway/apidocs ./apidocs
RUN rm -fv apidocs/permission.swagger.json
COPY gateway/third_party third_party
COPY wrapper.sh .
RUN chmod +x wrapper.sh
# gRPC gateway HTTP port, gRPC server port, Prometheus /metrics http port
EXPOSE 8000 6565 8080
CMD ./wrapper.sh
