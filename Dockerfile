# gRPC gateway gen

FROM --platform=$BUILDPLATFORM rvolosatovs/protoc:4.1.0 AS grpc-gateway-gen
WORKDIR /build
COPY gateway gateway
COPY src src
COPY proto.sh .
RUN sh proto.sh

# gRPC server builder

FROM --platform=$BUILDPLATFORM gradle:7.6.4-jdk17 AS grpc-server-builder
WORKDIR /build
COPY gradle gradle
COPY gradlew settings.gradle .
RUN sh gradlew wrapper -i
COPY *.gradle .
RUN sh gradlew dependencies -i
COPY src src
RUN sh gradlew build -i

# gRPC gateway builder

FROM --platform=$BUILDPLATFORM golang:1.23-alpine3.21 AS grpc-gateway-builder
ARG TARGETOS
ARG TARGETARCH
WORKDIR /build
COPY gateway/go.mod gateway/go.sum .
RUN go mod download
COPY gateway/ .
RUN rm -rf pkg/pb
COPY --from=grpc-gateway-gen /build/gateway/pkg/pb pkg/pb
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH \
        go build -o grpc-gateway .

# Extend Service Extension app

FROM eclipse-temurin:17-jre-alpine-3.21
WORKDIR /app
COPY --from=grpc-server-builder /build/target/*.jar app.jar
COPY jars/aws-opentelemetry-agent.jar .
COPY --from=grpc-gateway-builder /build/grpc-gateway .
COPY --from=grpc-gateway-gen /build/gateway/apidocs apidocs
RUN rm -fv apidocs/permission.swagger.json
COPY gateway/third_party third_party
COPY wrapper.sh .
# gRPC gateway HTTP port, gRPC server port, and /metrics HTTP port
EXPOSE 8000 6565 8080
CMD ["sh", "/app/wrapper.sh"]
