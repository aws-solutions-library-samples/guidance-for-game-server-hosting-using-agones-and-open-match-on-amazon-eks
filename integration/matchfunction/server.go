// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log"
	"net"
	"os"

	"github.com/pkg/errors"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"open-match.dev/open-match/pkg/pb"
)

type MatchFunctionService struct {
	grpc               *grpc.Server
	queryServiceClient pb.QueryServiceClient
	port               int
}

func Start(queryServiceAddr string, serverPort int) {
	omCert, err := os.ReadFile("./openmatch-tls/tls.crt")
	if err != nil {
		panic(err)
	}
	omKey, err := os.ReadFile("./openmatch-tls/tls.key")
	if err != nil {
		panic(err)
	}
	omCacert, err := os.ReadFile("./openmatch-tls/ca.crt")
	if err != nil {
		panic(err)
	}
	omDialOpts, err := createRemoteClusterDialOption(omCert, omKey, omCacert)
	if err != nil {
		panic(err)
	}
	conn, err := grpc.Dial(queryServiceAddr, omDialOpts)
	if err != nil {
		log.Fatalf("Failed to connect to Open Match, got %s", err.Error())
	}
	defer conn.Close()

	mmfService := MatchFunctionService{
		queryServiceClient: pb.NewQueryServiceClient(conn),
	}

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

func createRemoteClusterDialOption(clientCert, clientKey, caCert []byte) (grpc.DialOption, error) {
	cert, err := tls.X509KeyPair(clientCert, clientKey)
	if err != nil {
		return nil, err
	}

	tlsConfig := &tls.Config{MinVersion: tls.VersionTLS13, Certificates: []tls.Certificate{cert}}
	if len(caCert) != 0 {
		tlsConfig.RootCAs = x509.NewCertPool()
		if !tlsConfig.RootCAs.AppendCertsFromPEM(caCert) {
			return nil, errors.New("only PEM format is accepted for server CA")
		}
	}

	return grpc.WithTransportCredentials(credentials.NewTLS(tlsConfig)), nil
}
