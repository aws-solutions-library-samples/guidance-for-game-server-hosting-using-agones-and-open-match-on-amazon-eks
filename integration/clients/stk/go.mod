module agones-openmatch/stk

go 1.24.0

require agones-openmatch/allocation v0.0.0-00010101000000-000000000000

require (
	github.com/google/uuid v1.6.0 // indirect
	github.com/grpc-ecosystem/grpc-gateway/v2 v2.17.1 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	golang.org/x/net v0.48.0 // indirect
	golang.org/x/sys v0.39.0 // indirect
	golang.org/x/text v0.32.0 // indirect
	google.golang.org/genproto/googleapis/api v0.0.0-20251202230838-ff82c1b0f217 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20251202230838-ff82c1b0f217 // indirect
	google.golang.org/grpc v1.79.3 // indirect
	google.golang.org/protobuf v1.36.10 // indirect
	open-match.dev/open-match v1.8.1 // indirect
)

replace agones-openmatch/allocation => ../allocation-client
