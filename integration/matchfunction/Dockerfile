## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: MIT-0


FROM public.ecr.aws/docker/library/golang:1.21.4-alpine3.18 AS builder
RUN apk add --no-cache git
WORKDIR /app

# Leverage caching by copying go.mod and go.sum first
COPY go.mod go.sum ./
RUN go mod download

# Copy the remaining files and build
COPY . .
RUN go build -o matchfunction

# Final minimal image
FROM public.ecr.aws/docker/library/alpine:3.18
WORKDIR /app

# Copy only the binary and necessary files
COPY --from=builder /app/matchfunction /app/matchfunction
COPY *.cert *.key ./

USER 999
HEALTHCHECK CMD ["true"]

CMD ["./matchfunction"]
