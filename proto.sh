#!/bin/bash

set -e

rm -rf gateway/apidocs gateway/pkg/pb
mkdir -p gateway/apidocs gateway/pkg/pb
protoc-wrapper -I/usr/include \
                --proto_path=src/main/proto \
                --go_out=gateway/pkg/pb \
                --go_opt=paths=source_relative \
                --go-grpc_out=require_unimplemented_servers=false:gateway/pkg/pb \
                --go-grpc_opt=paths=source_relative src/main/proto/*.proto \
                --grpc-gateway_out=logtostderr=true:gateway/pkg/pb \
                --grpc-gateway_opt paths=source_relative \
                --openapiv2_out gateway/apidocs \
                --openapiv2_opt logtostderr=true \
                --openapiv2_opt use_go_templates=true
