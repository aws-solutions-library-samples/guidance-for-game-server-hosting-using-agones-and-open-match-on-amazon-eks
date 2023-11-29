// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package main

import (
	"agones-openmatch/allocation"
	"bufio"
	"flag"
	"fmt"
	"net"
	"os"
	"sync"

	"strings"
)

const (
	MSG_DISCONNECT = "Disconnected from the server.\n"
	CONN_TYPE      = "tcp"
)

var wg sync.WaitGroup

func Read(conn net.Conn) {
	reader := bufio.NewReader(conn)
	for {
		str, err := reader.ReadString('\n')
		if err != nil {
			fmt.Print(MSG_DISCONNECT)
			wg.Done()
			return
		}
		fmt.Print(str)
	}
}

func Write(conn net.Conn) {
	reader := bufio.NewReader(os.Stdin)
	writer := bufio.NewWriter(conn)

	for {
		str, err := reader.ReadString('\n')
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}

		_, err = writer.WriteString(str)
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}
		err = writer.Flush()
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}
	}
}
func ConnectGameServer(server string) {

	wg.Add(1)

	fmt.Printf("Connecting to ncat server")
	conn, err := net.Dial(CONN_TYPE, server)
	if err != nil {
		fmt.Println(err)
	}

	go Read(conn)
	go Write(conn)

	wg.Wait()
}

var omFrontendEndpoint string
var latencyUsEast1, latencyUsEast2 int

func main() {
	flag.StringVar(&omFrontendEndpoint, "frontend", "localhost:50504", "Open Match Frontend Endpoint")
	flag.IntVar(&latencyUsEast1, "latencyUsEast1", 100, "Latency to region us-east-1")
	flag.IntVar(&latencyUsEast2, "latencyUsEast2", 100, "Latency to region us-east-2")
	flag.Usage = func() {
		fmt.Printf("Usage: \n")
		fmt.Printf("player -frontend FrontendAddress:Port -latencyUsEast1 int -latencyUsEast2 int\n")
		flag.PrintDefaults()
	}
	flag.Parse()
	serverPort := allocation.GetServerAssignment(omFrontendEndpoint, latencyUsEast1, latencyUsEast2)
	fmt.Println(serverPort)
	serverPort = strings.Replace(serverPort, "\"", "", -1)
	serverPort = strings.Replace(serverPort, "connection:", "", 1)
	ConnectGameServer(serverPort)
}
