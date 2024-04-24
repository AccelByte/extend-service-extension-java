#!/bin/bash

rm -rf apidocs pkg/pb
mkdir -p apidocs pkg/pb
protoc-wrapper -I/usr/include \
                --proto_path=/src/main/proto \
                --go_out=pkg/pb \
                --go_opt=paths=source_relative \
                --go-grpc_out=require_unimplemented_servers=false:pkg/pb \
                --go-grpc_opt=paths=source_relative /src/main/proto/*.proto \
                --grpc-gateway_out=logtostderr=true:pkg/pb \
                --grpc-gateway_opt paths=source_relative \
                --openapiv2_out . \
                --openapiv2_opt logtostderr=true \
                --openapiv2_opt use_go_templates=true
mv *.swagger.json apidocs
