// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package main

import (
	"flag"
	"fmt"
	"os/exec"

	"agones-openmatch/allocation"
	"strings"
)

var omFrontendEndpoint, stkPath string
var latencyRegion1, latencyRegion2 int

func main() {

	flag.StringVar(&omFrontendEndpoint, "frontend", "localhost:50504", "Open Match Frontend Endpoint")
	flag.StringVar(&stkPath, "path", "supertuxkart", "SuperTuxKart binary path")
	flag.StringVar(&region1, "region1", "us-east-1", "Region 1")
	flag.IntVar(&latencyRegion1, "latencyRegion1", 100, "Latency to region 1")
	flag.StringVar(&region2, "region2", "us-east-2", "Region 2")
	flag.IntVar(&latencyRegion2, "latencyRegion2", 100, "Latency to region 2")
	flag.Usage = func() {
		fmt.Printf("Usage: \n")
		fmt.Printf("player -frontend FrontendAddress:Port -latencyRegion1 int -latencyRegion2 int -path /path/to/stk/binary\n")
		flag.PrintDefaults()
	}
	flag.Parse()
	serverPort := allocation.GetServerAssignment(omFrontendEndpoint, region1, latencyRegion1, region2, latencyRegion2)
	serverPort = strings.Replace(serverPort, "\"", "", -1)
	serverPort = strings.Replace(serverPort, "connection:", "", 1)
	fmt.Println(serverPort)
	// nosemgrep
	cmd := exec.Command(stkPath, "--owner-less", "--connect-now="+serverPort)
	if err := cmd.Run(); err != nil {
		fmt.Println("Error: ", err)
	}

	return
}
