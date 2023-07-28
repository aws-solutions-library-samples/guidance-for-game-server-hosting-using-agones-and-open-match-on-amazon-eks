// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	pba "agones.dev/agones/pkg/allocation/go"
	"github.com/pkg/errors"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"open-match.dev/open-match/pkg/pb"
)

// This Director continuously polls Open Match for the Match
// Profiles, submits the tickets to Agones Allocator service
// and returns the allocation to the Frontend.

var backendAddr, functionAddr, allocatorAddr, backendPort, certFile, keyFile, caFile, namespace, regions, ranges string
var functionPort, allocatorPort, interval int
var multicluster bool

func main() {
	flag.StringVar(&backendAddr, "backendAddr", "open-match-backend.open-match.svc.cluster.local", "Open Match Backend Address")
	flag.StringVar(&backendPort, "backendPort", "50505", "Open Match backend Port")
	flag.StringVar(&functionAddr, "functionAddr", "agones-openmatch-mmf.agones-openmatch.svc.cluster.local", "Open Match Function Address")
	flag.IntVar(&functionPort, "functionPort", 50502, "Open Match Function Port")
	flag.StringVar(&allocatorAddr, "allocatorAddr", "agones-allocator.agones-system.svc.cluster.local", "Agones Allocator Address")
	flag.IntVar(&allocatorPort, "allocatorPort", 443, "Agones Allocator Port")
	flag.StringVar(&certFile, "certFile", "client.crt", "Certificate File")
	flag.StringVar(&keyFile, "keyFile", "client.key", "Key File")
	flag.StringVar(&caFile, "caFile", "ca.crt", "CA File")
	flag.BoolVar(&multicluster, "multicluster", false, "Multi-Cluster allocation")
	flag.StringVar(&namespace, "namespace", "default", "Game servers namespace")
	flag.StringVar(&regions, "regions", "us-east-1,us-east-2", "List of regions, separated by ','")
	flag.StringVar(&ranges, "ranges", "0-24,25-49,50-74,74-99,100-9999", "List of latency ranges, in the format min-max, separated by ','")
	flag.IntVar(&interval, "interval", 5, "Polling interval, in seconds")

	flag.Usage = func() {
		fmt.Printf("Usage: \n")
		fmt.Printf("director -backendAddr addr -backendPort PortNumber -functionAddr addr -functionPort PortNumber -allocatorAddr addr -allocatorPort PortNumber -interval seconds\n")
		flag.PrintDefaults() // prints default usage
	}
	flag.Parse()
	certFile = "./agones-tls/" + certFile
	keyFile = "./agones-tls/" + keyFile
	caFile = "./agones-tls/" + caFile
	regionsArr := strings.Split(regions, ",")
	rangesArr := strings.Split(ranges, ",")

	// Connect to Open Match Backend.

	beCert, err := ioutil.ReadFile("./openmatch-tls/tls.crt")
	if err != nil {
		panic(err)
	}
	beKey, err := ioutil.ReadFile("./openmatch-tls/tls.key")
	if err != nil {
		panic(err)
	}
	beCacert, err := ioutil.ReadFile("./openmatch-tls/ca.crt")
	if err != nil {
		panic(err)
	}
	backendDialOpts, err := createRemoteClusterDialOption(beCert, beKey, beCacert)
	if err != nil {
		panic(err)
	}

	conn, err := grpc.Dial(backendAddr+":"+backendPort, backendDialOpts)

	if err != nil {
		log.Fatalf("Failed to connect to Open Match backend, got %s", err.Error())
	}

	defer conn.Close()
	be := pb.NewBackendServiceClient(conn)

	// Generate the profiles to fetch matches for.
	profiles := generateProfiles(regionsArr, rangesArr)
	log.Printf("Fetching matches for %v profiles", len(profiles))

	for range time.Tick(time.Second * time.Duration(interval)) {
		// Fetch matches for each profile
		var wg sync.WaitGroup
		for _, p := range profiles {
			wg.Add(1)
			go func(wg *sync.WaitGroup, p *pb.MatchProfile) {
				defer wg.Done()
				matches, err := fetch(be, p)
				if err != nil {
					log.Printf("Failed to fetch matches for profile %v, got %s", p.GetName(), err.Error())
					return
				}
				if len(matches) > 0 {
					log.Printf("Generated %v matches for profile %v", len(matches), p.GetName())
				}
				if err := assign(be, matches); err != nil {
					log.Printf("Failed to assign servers to matches, got %s", err.Error())
					return
				}
			}(&wg, p)
		}

		wg.Wait()
	}
}

func fetch(be pb.BackendServiceClient, p *pb.MatchProfile) ([]*pb.Match, error) {
	req := &pb.FetchMatchesRequest{
		Config: &pb.FunctionConfig{
			Host: functionAddr,
			Port: int32(functionPort),
			Type: pb.FunctionConfig_GRPC,
		},
		Profile: p,
	}

	stream, err := be.FetchMatches(context.Background(), req)
	if err != nil {
		log.Println()
		return nil, err
	}

	var result []*pb.Match
	for {
		resp, err := stream.Recv()
		if err == io.EOF {
			break
		}

		if err != nil {
			return nil, err
		}

		result = append(result, resp.GetMatch())
	}

	return result, nil
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

// Get allocation from the Agones Allocator Service
func getAllocation(matchId string) string {
	log.Printf("Requesting server allocation from Agones")
	endpoint := allocatorAddr + ":" + strconv.Itoa(allocatorPort)
	cert, err := ioutil.ReadFile(certFile)
	if err != nil {
		panic(err)
	}
	key, err := ioutil.ReadFile(keyFile)
	if err != nil {
		panic(err)
	}
	cacert, err := ioutil.ReadFile(caFile)
	if err != nil {
		panic(err)
	}
	request := &pba.AllocationRequest{
		Namespace: namespace,
		MultiClusterSetting: &pba.MultiClusterSetting{
			Enabled: multicluster,
		},
		GameServerSelectors: []*pba.GameServerSelector{
			{
				MatchLabels: map[string]string{"region": matchId[36:45]},
			},
		},
	}
	allocatorDialOpts, err := createRemoteClusterDialOption(cert, key, cacert)
	if err != nil {
		panic(err)
	}
	conn, err := grpc.Dial(endpoint, allocatorDialOpts)
	if err != nil {
		panic(err)
	}
	defer conn.Close()

	grpcClient := pba.NewAllocationServiceClient(conn)
	response, err := grpcClient.Allocate(context.Background(), request)
	if err != nil {
		panic(err)
	}
	return response.String()
}

func assign(be pb.BackendServiceClient, matches []*pb.Match) error {
	for _, match := range matches {
		ticketIDs := []string{}
		for _, t := range match.GetTickets() {
			ticketIDs = append(ticketIDs, t.Id)
		}
		allocation := getAllocation(match.GetMatchId())
		gameServer := regexp.MustCompile(`gameServerName:"(.*)" ports:<name:"(.*)" port:(.*) > address:"(.*)" nodeName:"(.*)"`)
		matches := gameServer.FindSubmatch([]byte(allocation))
		log.Printf("Agones Allocator response: %s", allocation)
		gameServerAddress := string(matches[4])
		log.Printf("Gameserver: %s", gameServerAddress)
		gameServerPort := string(matches[3])
		log.Printf("Port: %s", gameServerPort)
		conn := fmt.Sprintf(gameServerAddress + ":" + gameServerPort)
		req := &pb.AssignTicketsRequest{
			Assignments: []*pb.AssignmentGroup{
				{
					TicketIds: ticketIDs,
					Assignment: &pb.Assignment{
						Connection: conn,
					},
				},
			},
		}

		if _, err := be.AssignTickets(context.Background(), req); err != nil {
			return fmt.Errorf("AssignTickets failed for match %v, got %w", match.GetMatchId(), err)
		}

		log.Printf("Assigned server %s to match %v", gameServerAddress+":"+gameServerPort, match.GetMatchId())
	}

	return nil
}
