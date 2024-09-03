## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0

FROM public.ecr.aws/docker/library/golang:1.21.4-alpine3.18 AS go
RUN apk add git
WORKDIR /app
ENV GO111MODULE=on
ENV GOPROXY=direct,https://proxy.golang.org

COPY go.mod .
COPY go.sum .
RUN go mod download -x
COPY *.go .
RUN go build -o ncat-server .


FROM public.ecr.aws/docker/library/alpine:3.18
RUN apk add --no-cache --update --verbose nmap-ncat 
WORKDIR /app
COPY --from=go /app/ncat-server /app/ncat-server
RUN chmod +x /app/ncat-server
USER 999
HEALTHCHECK CMD ["true"]
ENTRYPOINT ["./ncat-server"]