# Copyright (c) 2022-2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash

IMAGE_NAME := $(shell basename "$$(pwd)")-app
BUILDER := extend-builder

TEST_SAMPLE_CONTAINER_NAME := sample-service-extension-test

.PHONY: build

proto:
	docker run -t --rm -u $$(id -u):$$(id -g) \
		-v $$(pwd):/data \
		-w /data \
		--entrypoint /bin/bash \
		rvolosatovs/protoc:4.1.0 \
			proto.sh

build: build_server build_gateway

build_server:
	docker run -t --rm \
			-u $$(id -u):$$(id -g) \
			-v $$(pwd):/data \
			-w /data \
			-e GRADLE_USER_HOME=.gradle \
			gradle:7.6.4-jdk17 \
			gradle -i --no-daemon generateProto \
					|| find .gradle -type f -iname 'protoc-*.exe' -exec chmod +x {} \;		# For MacOS docker host: Workaround to make protoc-*.exe executable
	docker run -t --rm \
			-u $$(id -u):$$(id -g) \
			-v $$(pwd):/data \
			-w /data \
			-e GRADLE_USER_HOME=.gradle \
			gradle:7.6.4-jdk17 \
			gradle -i --no-daemon build

build_gateway: proto

run_server:
	docker run -t --rm -u $$(id -u):$$(id -g) \
			-e GRADLE_USER_HOME=.gradle \
			--env-file .env \
			-v $$(pwd):/data/ \
			-w /data \
			-p 6565:6565 \
			-p 8080:8080 \
			gradle:7.6.4-jdk17 \
			gradle --console=plain -i --no-daemon run

run_gateway: proto
	docker run -it --rm -u $$(id -u):$$(id -g) \
		-e GOCACHE=/data/.cache/go-cache \
		-e GOPATH=/data/.cache/go-path \
		--env-file .env \
		-v $$(pwd):/data \
		-w /data/gateway \
		-p 8000:8000 \
		--add-host host.docker.internal:host-gateway \
		golang:1.20-alpine3.19 \
		go run main.go --grpc-addr host.docker.internal:6565

clean:
	docker run -t --rm -u $$(id -u):$$(id -g) \
			-v $$(pwd):/data/ \
			-w /data/ \
			-e GRADLE_USER_HOME=.gradle gradle:7.6.4-jdk17 \
			gradle --console=plain -i --no-daemon clean

image:
	docker buildx build -t ${IMAGE_NAME} --load .

imagex:
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build -t ${IMAGE_NAME} --platform linux/amd64 .
	docker buildx build -t ${IMAGE_NAME} --load .
	docker buildx rm --keep-state $(BUILDER)

imagex_push:
	@test -n "$(IMAGE_TAG)" || (echo "IMAGE_TAG is not set (e.g. 'v0.1.0', 'latest')"; exit 1)
	@test -n "$(REPO_URL)" || (echo "REPO_URL is not set"; exit 1)
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build -t ${REPO_URL}:${IMAGE_TAG} --platform linux/amd64 --push .
	docker buildx rm --keep-state $(BUILDER)
