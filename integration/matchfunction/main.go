// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package main

import (
	"flag"
	"fmt"
	"strconv"
	// "open-match.dev/open-match/tutorials/matchmaker101/matchfunction/mmf"
)

// This tutorial implenents a basic Match Function that is hosted in the below
// configured port. You can also configure the Open Match QueryService endpoint
// with which the Match Function communicates to query the Tickets.

func main() {
	var queryServiceAddr string
	var queryServicePort, serverPort, players int
	flag.StringVar(&queryServiceAddr, "queryServiceAddr", "open-match-query.open-match.svc.cluster.local", "Open Match Query Service Address")
	flag.IntVar(&queryServicePort, "queryServicePort", 50503, "Open Match Query Service Port")
	flag.IntVar(&serverPort, "serverPort", 50502, "Matchmaking Function Service Port")
	flag.IntVar(&players, "players", 4, "Number of players per match")
	flag.Usage = func() {
		fmt.Printf("Usage: \n")
		fmt.Printf("players -queryServiceAddr addr -queryServicePort PortNumber -serverPort PortNumber -players NumPlayers\n")
		flag.PrintDefaults() // prints default usage
	}
	flag.Parse()
	TicketsPerPoolPerMatch = players
	Start(queryServiceAddr+":"+strconv.Itoa(queryServicePort), serverPort)
}
