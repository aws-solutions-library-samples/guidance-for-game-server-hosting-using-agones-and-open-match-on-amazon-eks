// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io/ioutil"
	"log"
	"net"

	"github.com/pkg/errors"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"open-match.dev/open-match/pkg/pb"
)

// MatchFunctionService implements pb.MatchFunctionServer, the server generated
// by compiling the protobuf, by fulfilling the pb.MatchFunctionServer interface.
type MatchFunctionService struct {
	grpc               *grpc.Server
	queryServiceClient pb.QueryServiceClient
	port               int
}

// Start creates and starts the Match Function server and also connects to Open
// Match's queryService service. This connection is used at runtime to fetch tickets
// for pools specified in MatchProfile.
func Start(queryServiceAddr string, serverPort int) {
	// Connect to QueryService.

	omCert, err := ioutil.ReadFile("./openmatch-tls/tls.crt")
	if err != nil {
		panic(err)
	}
	omKey, err := ioutil.ReadFile("./openmatch-tls/tls.key")
	if err != nil {
		panic(err)
	}
	omCacert, err := ioutil.ReadFile("./openmatch-tls/ca.crt")
	if err != nil {
		panic(err)
	}
	omDialOpts, err := createRemoteClusterDialOption(omCert, omKey, omCacert)
	if err != nil {
		panic(err)
	}
	conn, err := grpc.Dial(queryServiceAddr, omDialOpts)
	// conn, err := grpc.Dial(queryServiceAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("Failed to connect to Open Match, got %s", err.Error())
	}
	defer conn.Close()

	mmfService := MatchFunctionService{
		queryServiceClient: pb.NewQueryServiceClient(conn),
	}

	// Create and host a new gRPC service on the configured port.
	creds, err := credentials.NewServerTLSFromFile("./openmatch-tls/tls.crt", "./openmatch-tls/tls.key")
	if err != nil {
		log.Fatalf("Failed to setup TLS with local files, error: %s", err)
	}
	var opts []grpc.ServerOption = []grpc.ServerOption{grpc.Creds(creds)}
	server := grpc.NewServer(opts...)
	pb.RegisterMatchFunctionServer(server, &mmfService)
	ln, err := net.Listen("tcp", fmt.Sprintf(":%d", serverPort))
	if err != nil {
		log.Fatalf("TCP net listener initialization failed for port %v, got %s", serverPort, err.Error())
	}

	log.Printf("TCP net listener initialized for port %v", serverPort)
	err = server.Serve(ln)
	if err != nil {
		log.Fatalf("gRPC serve failed, got %s", err.Error())
	}
}

// creates a grpc client dial option with TLS configuration.
func createRemoteClusterDialOption(clientCert, clientKey, caCert []byte) (grpc.DialOption, error) {
	// Load client cert
	cert, err := tls.X509KeyPair(clientCert, clientKey)
	if err != nil {
		return nil, err
	}

	tlsConfig := &tls.Config{MinVersion: tls.VersionTLS13, Certificates: []tls.Certificate{cert}}
	if len(caCert) != 0 {
		// Load CA cert, if provided, and trust the server certificate.
		// This is required for self-signed certs.
		tlsConfig.RootCAs = x509.NewCertPool()
		// tlsConfig.ServerName = "open-match-backend"
		if !tlsConfig.RootCAs.AppendCertsFromPEM(caCert) {
			return nil, errors.New("only PEM format is accepted for server CA")
		}
	}

	return grpc.WithTransportCredentials(credentials.NewTLS(tlsConfig)), nil
}
