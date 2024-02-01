# Copyright (c) 2022-2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash

IMAGE_NAME := $(shell basename "$$(pwd)")-app
BUILDER := grpc-plugin-server-builder

SHELL := /bin/bash

.PHONY: clean build image imagex

gen-gateway:
	rm -rfv gateway/pkg/pb/*
	mkdir -p gateway/pkg/pb
	docker run -t --rm -u $$(id -u):$$(id -g) \
		-v $$(pwd)/src:/source \
		-v $$(pwd)/gateway:/data \
		-w /data/ rvolosatovs/protoc:latest \
			--proto_path=/source/main/proto \
			--go_out=pkg/pb \
			--go_opt=paths=source_relative \
			--go-grpc_out=require_unimplemented_servers=false:pkg/pb \
			--go-grpc_opt=paths=source_relative /source/main/proto/*.proto \
			--grpc-gateway_out=logtostderr=true:pkg/pb \
			--grpc-gateway_opt paths=source_relative \
			--openapiv2_out . \
			--openapiv2_opt logtostderr=true \
			--openapiv2_opt use_go_templates=true

mod-gateway:
	docker run -t --rm -u $$(id -u):$$(id -g) \
		-v $$(pwd)/gateway:/data \
		-e GOCACHE=/tmp/cache \
		-w /data/ golang:1.20 \
		go mod tidy

clean:
	docker run -t --rm -u $$(id -u):$$(id -g) \
			-v $$(pwd):/data/ \
			-w /data/ \
			-e GRADLE_USER_HOME=.gradle gradle:7.5.1-jdk17 \
			gradle --console=plain -i --no-daemon clean

build: gen-gateway mod-gateway
	docker run -t --rm -u $$(id -u):$$(id -g) \
			-v $$(pwd):/data/ -w /data/ \
			-e GRADLE_USER_HOME=.gradle gradle:7.5.1-jdk17 \
			gradle --console=plain -i --no-daemon build

image:
	docker buildx build -t ${IMAGE_NAME} --load .

image-service:
	docker build -f Dockerfile.service -t ${IMAGE_NAME}-service .

image-gateway:
	docker build -f Dockerfile.gateway -t ${IMAGE_NAME}-gateway .

imagex:
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build -t ${IMAGE_NAME} --platform linux/arm64/v8,linux/amd64 .
	docker buildx build -t ${IMAGE_NAME} --load .
	docker buildx rm --keep-state $(BUILDER)

imagex_push:
	@test -n "$(IMAGE_VERSION)" || (echo "IMAGE_VERSION is not set"; exit 1)
	@test -n "$(REPO_URL)" || (echo "REPO_URL is not set"; exit 1)
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build -t ${IMAGE_PREFIX}${IMAGE_NAME}:${IMAGE_VERSION} --platform linux/arm64/v8,linux/amd64 --push .
	docker buildx rm --keep-state $(BUILDER)


#imagex:
#	docker buildx inspect ${IMAGE_NAME}-builder \
#			|| docker buildx create --name ${IMAGE_NAME}-builder --use
#	docker buildx build -t ${IMAGE_NAME} --platform linux/arm64,linux/amd64 .
#	docker buildx build -t ${IMAGE_NAME} --load .
#	#docker buildx rm ${IMAGE_NAME}-builder
#
#imagex_push:
#	@test -n "$(IMAGE_TAG)" || (echo "IMAGE_TAG is not set (e.g. 'v0.1.0', 'latest')"; exit 1)
#	@test -n "$(REPO_URL)" || (echo "REPO_URL is not set"; exit 1)
#	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
#	docker buildx build -t ${REPO_URL}:${IMAGE_TAG} --platform linux/arm64,linux/amd64 --push .
#	docker buildx rm --keep-state $(BUILDER)

