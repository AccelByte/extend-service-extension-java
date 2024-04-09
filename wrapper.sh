#!/bin/bash

java -javaagent:aws-opentelemetry-agent.jar -jar app.jar &

./grpc_gateway &

wait -n

exit $?

# https://docs.docker.com/config/containers/multi-service_container/#use-a-wrapper-script