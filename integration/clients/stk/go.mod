module agones-openmatch/stk

go 1.19

require agones-openmatch/allocation v0.0.0-00010101000000-000000000000

require (
	github.com/golang/protobuf v1.5.3 // indirect
	github.com/google/uuid v1.3.0 // indirect
	github.com/grpc-ecosystem/grpc-gateway/v2 v2.15.0 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	golang.org/x/net v0.9.0 // indirect
	golang.org/x/sys v0.7.0 // indirect
	golang.org/x/text v0.9.0 // indirect
	google.golang.org/genproto v0.0.0-20230410155749-daa745c078e1 // indirect
	google.golang.org/grpc v1.56.3 // indirect
	google.golang.org/protobuf v1.30.0 // indirect
	open-match.dev/open-match v1.7.0 // indirect
)

replace agones-openmatch/allocation => ../allocation-client
