# Copyright (c) 2022-2025 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash

PROJECT_NAME := $(shell basename "$$(pwd)")
GRADLE_IMAGE := gradle:7.6.4-jdk17
GOLANG_IMAGE := golang:1.24-alpine3.21
PROTOC_IMAGE := rvolosatovs/protoc:4.1.0

BUILD_CACHE_VOLUME := $(shell echo '$(PROJECT_NAME)' | sed 's/[^a-zA-Z0-9_-]//g')-build-cache

.PHONY: build

build: build_server build_gateway

clean:
	docker run -t --rm \
			-v $(BUILD_CACHE_VOLUME):/tmp/build-cache \
			$(GRADLE_IMAGE) \
			chown $$(id -u):$$(id -g) /tmp/build-cache		# For MacOS docker host: Workaround for /tmp/build-cache folder owned by root
	docker run -t --rm \
			-u $$(id -u):$$(id -g) \
			-v $(BUILD_CACHE_VOLUME):/tmp/build-cache \
			-v $$(pwd):/data \
			-w /data \
			$(GRADLE_IMAGE) \
			gradle \
					--gradle-user-home /tmp/build-cache/gradle \
					--project-cache-dir /tmp/build-cache/gradle \
					--console=plain \
					--info \
					--no-daemon \
					clean

proto:
	docker run -t --rm \
		-u $$(id -u):$$(id -g) \
		-v $$(pwd):/data \
		-w /data \
		--entrypoint /bin/bash \
		${PROTOC_IMAGE} \
		proto.sh

build_server:
	docker run -t --rm \
			-v $(BUILD_CACHE_VOLUME):/tmp/build-cache \
			$(GRADLE_IMAGE) \
			chown $$(id -u):$$(id -g) /tmp/build-cache		# For MacOS docker host: Workaround for /tmp/build-cache folder owned by root
	docker run -t --rm \
			-u $$(id -u):$$(id -g) \
			-v $(BUILD_CACHE_VOLUME):/tmp/build-cache \
			-v $$(pwd):/data \
			-w /data \
			$(GRADLE_IMAGE) \
			gradle \
					--gradle-user-home /tmp/build-cache/gradle \
					--project-cache-dir /tmp/build-cache/gradle \
					--console=plain \
					--info \
					--no-daemon \
					build

build_gateway: proto

run_server:
	docker run -t --rm -u $$(id -u):$$(id -g) \
			--env-file .env \
			-v $(BUILD_CACHE_VOLUME):/tmp/build-cache \
			-v $$(pwd):/data/ \
			-w /data \
			-p 6565:6565 \
			-p 8080:8080 \
			${GRADLE_IMAGE} \
			gradle \
					--gradle-user-home /tmp/build-cache/gradle \
					--project-cache-dir /tmp/build-cache/gradle \
					--console=plain \
					--info \
					--no-daemon \
					run

run_gateway: proto
	docker run -it --rm -u $$(id -u):$$(id -g) \
		-e GOCACHE=/tmp/build-cache/go/cache \
		-e GOMODCACHE=/tmp/build-cache/go/modcache \
		--env-file .env \
		-v $(BUILD_CACHE_VOLUME):/tmp/build-cache \
		-v $$(pwd):/data \
		-w /data/gateway \
		-p 8000:8000 \
		--add-host host.docker.internal:host-gateway \
		${GOLANG_IMAGE} \
		go run main.go --grpc-addr host.docker.internal:6565