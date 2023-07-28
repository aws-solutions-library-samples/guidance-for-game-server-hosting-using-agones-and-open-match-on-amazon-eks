// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"regexp"
	"time"

	sdk "agones.dev/agones/sdks/go"
)

// main intercepts the output of ncat and uses it
// to determine if the game server is ready or not.
func main() {
	log.SetPrefix("[wrapper] ")
	port := flag.String("p", "", "ncat listening port")

	// Since player tracking is not on by default, it is behind this flag.
	// If it is off, still log messages about players, but don't actually call the player tracking functions.
	enablePlayerTracking := flag.Bool("player-tracking", false, "If true, player tracking will be enabled.")
	flag.Parse()

	log.Println("Connecting to Agones with the SDK")
	s, err := sdk.NewSDK()
	if err != nil {
		log.Fatalf("could not connect to SDK: %v", err)
	}

	if *enablePlayerTracking {
		if err = s.Alpha().SetPlayerCapacity(8); err != nil {
			log.Fatalf("could not set play count: %v", err)
		}
	}

	log.Println("Starting health checking")
	go doHealth(s)

	log.Println("Starting wrapper for ncat")
	log.Printf("ncat server running on port %s \n", *port)

	// cmdString := strings.Split(*port, " ")
	// command, args := cmdString[0], cmdString[1:]

	cmd := exec.Command("/usr/bin/ncat", "--chat", "--listen", "-p "+*port, "-vvv") // #nosec
	// cmd.Stderr = os.Stderr
	// cmd.Stdout = os.Stdout
	cmdReader, err := cmd.StderrPipe()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error creating StdoutPipe for Cmd", err)
		return
	}

	playersConnected := false
	scanner := bufio.NewScanner(cmdReader)
	go func() {
		for scanner.Scan() {

			str := scanner.Text()
			// fmt.Println("str")
			fmt.Println(str)
			// matched, _ := regexp.MatchString(`Listening on?`, str)
			// if matched {
			// 	fmt.Println("str")
			// }
			// }

			action, player := handleLogLine(str)
			switch action {
			case "READY":
				log.Print("READY")
				if err := s.Ready(); err != nil {
					log.Fatal("failed to mark server ready")
				}
			case "PLAYERJOIN":
				playersConnected = true
				if player == nil {
					log.Print("could not determine player")
					break
				}
				if *enablePlayerTracking {
					result, err := s.Alpha().PlayerConnect(*player)
					if err != nil {
						log.Print(err)
					} else {
						log.Print(result)
					}
				}
			case "PLAYERLEAVE":
				if player == nil {
					log.Print("could not determine player")
					break
				}
				if *enablePlayerTracking {
					result, err := s.Alpha().PlayerDisconnect(*player)
					if err != nil {
						log.Print(err)
					} else {
						log.Print(result)
					}
				}
			case "SHUTDOWN":
				if playersConnected {
					if err := s.Shutdown(); err != nil {
						log.Fatal(err)
					}
					log.Print("server has no more players. shutting down")
					os.Exit(0)
				}
			}
		}
		log.Fatal("tail ended")
	}()

	if err := cmd.Start(); err != nil {
		log.Fatalf("error starting cmd: %v", err)
	}

	err = cmd.Wait()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error waiting for Cmd", err)
		return
	}
}

// doHealth sends the regular Health Pings
func doHealth(sdk *sdk.SDK) {
	tick := time.Tick(2 * time.Second)
	for {
		if err := sdk.Health(); err != nil {
			log.Fatalf("could not send health ping: %v", err)
		}
		<-tick
	}
}

// handleLogLine compares the log line to a series of regexes to determine if any action should be taken.
// TODO: This could probably be handled better with a custom type rather than just (string, *string)
func handleLogLine(line string) (string, *string) {
	// fmt.Fprintln(os.Stderr, "Line: %s", line)
	// The various regexes that match server lines
	playerJoin := regexp.MustCompile(`on file descriptor \b(\w+)\.$`)
	playerLeave := regexp.MustCompile(`Closing connection`)
	noMorePlayers := regexp.MustCompile(`Broker connection count is 0`)
	serverStart := regexp.MustCompile(`Version`)

	// Start the server
	if serverStart.MatchString(line) {
		log.Print("server ready")
		return "READY", nil
	}

	// Player tracking
	if playerJoin.MatchString(line) {
		matches := playerJoin.FindSubmatch([]byte(line))
		player := string(matches[1])
		log.Printf("Player %s joined\n", player)
		log.Printf("Player joined\n")
		return "PLAYERJOIN", &player
		// return "PLAYERJOIN", nil
	}
	if playerLeave.MatchString(line) {
		// matches := playerLeave.FindSubmatch([]byte(line))
		// player := string(matches[1])
		// log.Printf("Player %s disconnected", player)
		log.Printf("Player disconnected")
		// return "PLAYERLEAVE", &player
		return "PLAYERLEAVE", nil
	}

	// All the players left, send a shutdown
	if noMorePlayers.MatchString(line) {
		return "SHUTDOWN", nil
	}
	return "", nil
}
