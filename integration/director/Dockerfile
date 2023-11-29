## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0

FROM public.ecr.aws/docker/library/golang:1.20.3-alpine3.17 as go
RUN apk add git
WORKDIR /app
ENV GO111MODULE=on
ENV GOPROXY=direct,https://proxy.golang.org

COPY go.mod .
COPY go.sum .
RUN go mod download -x
COPY *.go .
RUN go build -o director .

FROM public.ecr.aws/docker/library/alpine:3.17

WORKDIR /app
COPY --from=go /app/director /app/director
USER 999
HEALTHCHECK CMD ["true"]

CMD ["./director"]
