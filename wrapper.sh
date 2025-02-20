#!/bin/bash

# https://docs.docker.com/config/containers/multi-service_container/#use-a-wrapper-script

java -javaagent:aws-opentelemetry-agent.jar -jar app.jar &

./grpc-gateway &

wait -n

exit $?
