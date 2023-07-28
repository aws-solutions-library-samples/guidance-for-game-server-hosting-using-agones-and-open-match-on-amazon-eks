// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package allocation

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log"

	"github.com/google/uuid"
	"github.com/pkg/errors"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"

	// "google.golang.org/grpc/credentials/insecure"
	"io/ioutil"

	"open-match.dev/open-match/pkg/pb"
)

const GAME_MODE_SESSION = "mode.session"

type MatchRequest struct {
	Ticket     *pb.Ticket
	Tags       []string
	StringArgs map[string]string
	DoubleArgs map[string]float64
}

type Player struct {
	UID          string
	MatchRequest *MatchRequest
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
		tlsConfig.ServerName = "open-match-evaluator"
		if !tlsConfig.RootCAs.AppendCertsFromPEM(caCert) {
			return nil, errors.New("only PEM format is accepted for server CA")
		}
	}

	return grpc.WithTransportCredentials(credentials.NewTLS(tlsConfig)), nil
}

func GetServerAssignment(omFrontendEndpoint string, latencyUsEast1 int, latencyUsEast2 int) string {
	log.Printf("Connecting to Open Match Frontend: " + omFrontendEndpoint)
	cert, err := ioutil.ReadFile("public.cert")
	if err != nil {
		panic(err)
	}
	key, err := ioutil.ReadFile("private.key")
	if err != nil {
		panic(err)
	}
	cacert, err := ioutil.ReadFile("publicCA.cert")
	if err != nil {
		panic(err)
	}
	dialOpts, err := createRemoteClusterDialOption(cert, key, cacert)
	if err != nil {
		panic(err)
	}
	conn, err := grpc.Dial(omFrontendEndpoint, dialOpts)
	// conn, err := grpc.Dial(omFrontendEndpoint, dialOpts, grpc.WithAuthority("open-match-frontend"))
	if err != nil {
		log.Fatalf("Failed to connect to Open Match Frontend, got %s", err.Error())
	}

	feService := pb.NewFrontendServiceClient(conn)

	player := &Player{
		UID: uuid.New().String(),
		MatchRequest: &MatchRequest{
			Tags: []string{GAME_MODE_SESSION},
			// StringArgs: map[string]string{"region": "us-east-1", "world": "Orion"},
			DoubleArgs: map[string]float64{
				"latency-us-east-1": float64(latencyUsEast1),
				"latency-us-east-2": float64(latencyUsEast2),
			},
		}}
	req := &pb.CreateTicketRequest{
		Ticket: &pb.Ticket{
			SearchFields: &pb.SearchFields{
				Tags: player.MatchRequest.Tags,
				// StringArgs: player.MatchRequest.StringArgs,
				DoubleArgs: player.MatchRequest.DoubleArgs,
			},
		},
	}
	ticket, err := feService.CreateTicket(context.Background(), req)
	if err != nil {
		log.Fatalf("Error: %v", err)
		// return err
	}
	log.Printf("Ticket ID: %s\n", ticket.Id)
	// assigned := false
	log.Printf("Waiting for ticket assignment")
	for {
		req := &pb.GetTicketRequest{
			TicketId: ticket.Id,
		}
		ticket, err := feService.GetTicket(context.Background(), req)

		if err != nil {
			return fmt.Sprintf("Was not able to get a ticket, err: %s\n", err.Error())
		}

		if ticket.Assignment != nil {
			log.Printf("Ticket assignment: %s\n", ticket.Assignment)
			log.Printf("Disconnecting from Open Match Frontend")

			defer conn.Close()
			return ticket.Assignment.String()
		}

	}
}
