FROM alpine:3.18
WORKDIR /workspace
RUN apk --no-cache add bash curl docker-cli-buildx git go gradle jq make gcompat \
        && apk add --update-cache --upgrade curl