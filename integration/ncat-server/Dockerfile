## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0

FROM public.ecr.aws/docker/library/golang:1.20.3-alpine3.17 as go
RUN apk add git
WORKDIR /app
ENV GO111MODULE=on
ENV GOPROXY=direct

COPY go.mod .
COPY go.sum .
RUN go mod download -x
COPY *.go .
RUN go build -o ncat-server .


FROM public.ecr.aws/docker/library/alpine:3.17
RUN apk add --no-cache --update --verbose nmap-ncat 
WORKDIR /app
COPY --from=go /app/ncat-server /app/ncat-server
RUN chmod +x /app/ncat-server
USER 999
HEALTHCHECK CMD ["true"]
ENTRYPOINT ["./ncat-server"]