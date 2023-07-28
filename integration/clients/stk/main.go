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
var latencyUsEast1, latencyUsEast2 int

func main() {

	flag.StringVar(&omFrontendEndpoint, "frontend", "localhost:50504", "Open Match Frontend Endpoint")
	flag.StringVar(&stkPath, "path", "supertuxkart", "SuperTuxKart binary path")
	flag.IntVar(&latencyUsEast1, "latencyUsEast1", 100, "Latency to region us-east-1")
	flag.IntVar(&latencyUsEast2, "latencyUsEast2", 100, "Latency to region us-east-2")
	flag.Usage = func() {
		fmt.Printf("Usage: \n")
		fmt.Printf("player -frontend FrontendAddress:Port -latencyUsEast1 int -latencyUsEast2 int -path /path/to/stk/binary\n")
		flag.PrintDefaults() // prints default usage
	}
	flag.Parse()
	serverPort := allocation.GetServerAssignment(omFrontendEndpoint, latencyUsEast1, latencyUsEast2)
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
