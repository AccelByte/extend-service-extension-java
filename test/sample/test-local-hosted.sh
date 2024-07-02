#!/usr/bin/env bash

# Prerequisites: bash, curl, go, jq

set -e
set -o pipefail
#set -x

APP_BASE_URL=http://localhost:8000
APP_BASE_PATH="guild"

function clean_up()
{
  kill -9 $SERVICE_PID $GATEWAY_PID
}

trap clean_up EXIT

echo '# Build and run Extend app locally'

(cd gateway && go build -buildvcs=false -o gateway)
bash gradlew -i --no-daemon generateProto \
    || find $GRADLE_USER_HOME -type f -iname 'protoc-*.exe' -exec chmod +x {} \;   # For MacOS docker host: Workaround to make sure protoc-*.exe is executable
bash gradlew -i --no-daemon build
(cd gateway && BASE_PATH=/$APP_BASE_PATH ./gateway) & GATEWAY_PID=$!
bash gradlew -i --no-daemon run & SERVICE_PID=$!

(for _ in {1..12}; do bash -c "timeout 1 echo > /dev/tcp/127.0.0.1/8000" 2>/dev/null && exit 0 || sleep 5s; done; exit 1)
(for _ in {1..12}; do bash -c "timeout 1 echo > /dev/tcp/127.0.0.1/8080" 2>/dev/null && exit 0 || sleep 5s; done; exit 1)

if [ $? -ne 0 ]; then
  echo "Failed to run Extend app locally"
  exit 1
fi

echo  "# Waiting until Extend app is up ..."

sleep 60

echo '# Testing Extend app using demo script'

export SERVICE_BASE_URL=$APP_BASE_URL
export SERVICE_BASE_PATH=$APP_BASE_PATH

bash demo.sh
