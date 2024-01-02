// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package main

import (
	"compress/gzip"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
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

var backendAddr, functionAddr, allocatorAddr, backendPort, certFile, keyFile, caFile, namespace, region, regions, ranges, regionPattern string
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
	accelerator := make(map[string]string)
	// Regular expression for AWS regions
	regionPattern = `(us(-gov)?|af|ap|ca|cn|eu|il|me|sa)-(central|(north|south)?(east|west)?)-\d`

	log.Printf("Opening files")

	gzippedMapping1, err := os.Open("/app/global-accelerator-mapping/mapping1.gz")
	if err != nil {
		log.Fatal(err)
	}
	defer gzippedMapping1.Close()

	gzippedMapping2, err := os.Open("/app/global-accelerator-mapping/mapping2.gz")
	if err != nil {
		log.Fatal(err)
	}
	defer gzippedMapping2.Close()

	acceleratorFile1, err := os.ReadFile("/app/global-accelerator-mapping/accelerator1")
	if err != nil {
		log.Fatal(err)
	}
	accelerator[regionsArr[0]] = string(acceleratorFile1)
	acceleratorFile2, err := os.ReadFile("/app/global-accelerator-mapping/accelerator2")
	if err != nil {
		log.Fatal(err)
	}
	accelerator[regionsArr[1]] = string(acceleratorFile2)

	mapping1Reader, err := gzip.NewReader(gzippedMapping1)
	defer mapping1Reader.Close()

	mapping2Reader, err := gzip.NewReader(gzippedMapping2)
	defer mapping2Reader.Close()

	mapping1, err := io.ReadAll(mapping1Reader)
	if err != nil {
		panic(err)
	}
	mapping2, err := io.ReadAll(mapping2Reader)
	if err != nil {
		panic(err)
	}
	mappingJson := make(map[string]map[string]int)
	var mapping1Json, mapping2Json map[string]int
	err = json.Unmarshal(mapping1, &mapping1Json)
	if err != nil {
		log.Fatal("Error during Unmarshal() mapping1: ", err)
	}
	mappingJson[regionsArr[0]] = mapping1Json
	err = json.Unmarshal(mapping2, &mapping2Json)
	if err != nil {
		log.Fatal("Error during Unmarshal() mapping2: ", err)
	}
	mappingJson[regionsArr[1]] = mapping2Json
	err = json.Unmarshal(mapping2, &mapping2Json)
	if err != nil {
		log.Fatal("Error during Unmarshal() mapping2: ", err)
	}

	// Connect to Open Match Backend.

	beCert, err := os.ReadFile("./openmatch-tls/tls.crt")
	if err != nil {
		panic(err)
	}
	beKey, err := os.ReadFile("./openmatch-tls/tls.key")
	if err != nil {
		panic(err)
	}
	beCacert, err := os.ReadFile("./openmatch-tls/ca.crt")
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
				if err := assign(be, matches, mappingJson, accelerator); err != nil {
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

// Creates a grpc client dial option with TLS configuration.
func createRemoteClusterDialOption(clientCert, clientKey, caCert []byte) (grpc.DialOption, error) {
	// Load client cert
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

// Get allocation from the Agones Allocator Service
func getAllocation(matchId string) *pba.AllocationResponse {
	log.Printf("Requesting server allocation from Agones")
	endpoint := allocatorAddr + ":" + strconv.Itoa(allocatorPort)
	cert, err := os.ReadFile(certFile)
	if err != nil {
		panic(err)
	}
	key, err := os.ReadFile(keyFile)
	if err != nil {
		panic(err)
	}
	cacert, err := os.ReadFile(caFile)
	if err != nil {
		panic(err)
	}
	regexpPattern := regexp.MustCompile(regionPattern)
	region := regexpPattern.FindString(matchId)

	request := &pba.AllocationRequest{
		Namespace: namespace,
		MultiClusterSetting: &pba.MultiClusterSetting{
			Enabled: multicluster,
		},
		GameServerSelectors: []*pba.GameServerSelector{
			{
				MatchLabels: map[string]string{"region": region},
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
	return response
}

func assign(be pb.BackendServiceClient, matches []*pb.Match, mappingJson map[string]map[string]int, accelerator map[string]string) error {
	for _, match := range matches {
		ticketIDs := []string{}
		for _, t := range match.GetTickets() {
			ticketIDs = append(ticketIDs, t.Id)
		}
		matchId := match.GetMatchId()
		regexpPattern := regexp.MustCompile(regionPattern)
		region = regexpPattern.FindString(matchId)

		allocation := getAllocation(matchId)
		log.Printf("Agones Allocator response: %s", allocation.String())

		var gameServerAddress string
		for _, addr := range allocation.GetAddresses() {
			if addr.GetType() == "InternalIP" {
				gameServerAddress = addr.GetAddress()
				break
			}
		}
		log.Printf("Gameserver address: %s", gameServerAddress)
		var gameServerPort int32
		for _, p := range allocation.GetPorts() {
			if p.GetName() == "default" {
				gameServerPort = p.GetPort()
				break
			}
		}
		log.Printf("Port: %s", strconv.Itoa(int(gameServerPort)))
		internalIpPort := gameServerAddress + ":" + strconv.Itoa(int(gameServerPort))
		log.Printf("internalIpPort: %s", internalIpPort)
		globalAcceleratorPort, _ := mappingJson[region][internalIpPort]
		conn := accelerator[region] + ":" + strconv.Itoa(globalAcceleratorPort)
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
		log.Printf("Assigned server %s to match %v", accelerator[region]+":"+strconv.Itoa(globalAcceleratorPort), match.GetMatchId())
	}

	return nil
}
