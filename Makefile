# Copyright (c) 2022-2025 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash

BUILDER := extend-builder
IMAGE_NAME := $(shell basename "$$(pwd)")-app

GRADLE_IMAGE := gradle:7.6.4-jdk17
GOLANG_IMAGE := golang:1.23-alpine3.21
PROTOC_IMAGE := rvolosatovs/protoc:4.1.0

.PHONY: build

proto:
	docker run -t --rm \
		-u $$(id -u):$$(id -g) \
		-v $$(pwd):/data \
		-w /data \
		--entrypoint /bin/bash \
		${PROTOC_IMAGE} \
		proto.sh

build: build_server build_gateway

build_server:
	docker run -t --rm \
			-e GRADLE_USER_HOME=.cache/gradle \
			-u $$(id -u):$$(id -g) \
			-v $$(pwd):/data \
			-w /data \
			${GRADLE_IMAGE} \
			gradle --console=plain -i --no-daemon generateProto \
					|| find .cache/gradle -type f -iname 'protoc-*.exe' -exec chmod +x {} \;		# For MacOS docker host: Workaround to make protoc-*.exe executable
	docker run -t --rm \
			-e GRADLE_USER_HOME=.cache/gradle \
			-u $$(id -u):$$(id -g) \
			-v $$(pwd):/data \
			-w /data \
			${GRADLE_IMAGE} \
			gradle --console=plain -i --no-daemon build

build_gateway: proto

run_server:
	docker run -t --rm -u $$(id -u):$$(id -g) \
			-e GRADLE_USER_HOME=.cache/gradle \
			--env-file .env \
			-v $$(pwd):/data/ \
			-w /data \
			-p 6565:6565 \
			-p 8080:8080 \
			${GRADLE_IMAGE} \
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
		${GOLANG_IMAGE} \
		go run main.go --grpc-addr host.docker.internal:6565

clean:
	docker run -t --rm \
			-u $$(id -u):$$(id -g) \
			-e GRADLE_USER_HOME=.cache/gradle \
			-v $$(pwd):/data/ \
			-w /data/ \
			${GRADLE_IMAGE} \
			gradle --console=plain -i --no-daemon clean

image:
	docker buildx build -t ${IMAGE_NAME} --load .

imagex:
	docker buildx inspect ${BUILDER} || docker buildx create --name ${BUILDER} --use
	docker buildx build -t ${IMAGE_NAME} --platform linux/amd64 .
	docker buildx build -t ${IMAGE_NAME} --load .
	docker buildx rm --keep-state ${BUILDER}

imagex_push:
	@test -n "${IMAGE_TAG}" || (echo "IMAGE_TAG is not set (e.g. 'v0.1.0', 'latest')"; exit 1)
	@test -n "${REPO_URL}" || (echo "REPO_URL is not set"; exit 1)
	docker buildx inspect ${BUILDER} || docker buildx create --name ${BUILDER} --use
	docker buildx build -t ${REPO_URL}:${IMAGE_TAG} --platform linux/amd64 --push .
	docker buildx rm --keep-state ${BUILDER}
