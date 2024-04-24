# Copyright (c) 2022-2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash

IMAGE_NAME := $(shell basename "$$(pwd)")-app
BUILDER := grpc-plugin-server-builder

SHELL := /bin/bash

PROJECT_DIR ?= $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: clean build image imagex

gen_gateway:
	docker run -t --rm -u $$(id -u):$$(id -g) \
		-v $$(pwd)/src:/src \
		-v $$(pwd)/gateway:/gateway \
		-w /gateway \
		--entrypoint /bin/bash \
		rvolosatovs/protoc:4.1.0 \
			gen_gateway.sh

build: build_server build_gateway

build_server:
	docker run -t --rm -u $$(id -u):$$(id -g) \
			-v $(PROJECT_DIR):/data/ -w /data/ \
			-e GRADLE_USER_HOME=.gradle gradle:7.5.1-jdk17 \
			gradle --console=plain -i --no-daemon clean build

build_gateway: gen_gateway

run_server:
	docker run -t --rm -u $$(id -u):$$(id -g) \
			-e GRADLE_USER_HOME=.gradle \
			--env-file .env \
			-v $(PROJECT_DIR):/data/ \
			-w /data \
			-p 6565:6565 \
			-p 8080:8080 \
			gradle:7.5.1-jdk17 \
			gradle --console=plain -i --no-daemon run

run_gateway: gen_gateway
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
			-v $(PROJECT_DIR):/data/ \
			-w /data/ \
			-e GRADLE_USER_HOME=.gradle gradle:7.5.1-jdk17 \
			gradle --console=plain -i --no-daemon clean

image:
	docker buildx build -t ${IMAGE_NAME} --load .

imagex: build
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build -t ${IMAGE_NAME} --platform linux/amd64 .
	docker buildx build -t ${IMAGE_NAME} --load .
	docker buildx rm --keep-state $(BUILDER)

imagex_push: build
	@test -n "$(IMAGE_TAG)" || (echo "IMAGE_TAG is not set (e.g. 'v0.1.0', 'latest')"; exit 1)
	@test -n "$(REPO_URL)" || (echo "REPO_URL is not set"; exit 1)
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build -t ${REPO_URL}:${IMAGE_TAG} --platform linux/amd64 --push .
	docker buildx rm --keep-state $(BUILDER)

test_functional_local_hosted:
	@test -n "$(ENV_PATH)" || (echo "ENV_PATH is not set"; exit 1)
	docker build --tag service-extension-test-functional -f test/functional/Dockerfile test/functional && \
	docker run --rm -t \
		--env-file $(ENV_PATH) \
		-e GOCACHE=/data/.cache/go-build \
		-e GOPATH=/data/.cache/mod \
		-u $$(id -u):$$(id -g) \
		-v $$(pwd):/data \
		-w /data service-extension-test-functional bash ./test/functional/test-local-hosted.sh

test_functional_accelbyte_hosted:
	@test -n "$(ENV_PATH)" || (echo "ENV_PATH is not set"; exit 1)
ifeq ($(shell uname), Linux)
	$(eval DARGS := -u $$(shell id -u):$$(shell id -g) --group-add $$(shell getent group docker | cut -d ':' -f 3))
endif
	docker build --tag service-extension-test-functional -f test/functional/Dockerfile test/functional && \
	docker run --rm -t \
		--env-file $(ENV_PATH) \
		-e PROJECT_DIR=$(PROJECT_DIR) \
		-e GOCACHE=/data/.cache/go-build \
		-e GOPATH=/data/.cache/mod \
		-e DOCKER_CONFIG=/tmp/.docker \
		$(DARGS) \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v $$(pwd):/data \
		-w /data service-extension-test-functional bash ./test/functional/test-accelbyte-hosted.sh
