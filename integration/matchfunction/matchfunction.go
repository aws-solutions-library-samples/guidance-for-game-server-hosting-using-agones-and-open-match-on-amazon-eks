// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package main

import (
	"fmt"
	"log"
	"sort"
	"time"

	// "github.com/golang/protobuf/ptypes"
	"google.golang.org/protobuf/types/known/anypb"
	"open-match.dev/open-match/pkg/matchfunction"
	"open-match.dev/open-match/pkg/pb"
)

const (
	matchName = "basic-matchfunction"

	// Uncomment if following the tutorial
	// TicketsPerPoolPerMatch = 4
)

var TicketsPerPoolPerMatch int

// Run is this match function's implementation of the gRPC call defined in api/matchfunction.proto.
func (s *MatchFunctionService) Run(req *pb.RunRequest, stream pb.MatchFunction_RunServer) error {
	// Fetch tickets for the pools specified in the Match Profile.
	// log.Printf("Generating proposals for function %v", req.GetProfile().GetName())
	// log.Printf("------------------------------START-----------------------------------------")

	poolTickets, err := matchfunction.QueryPools(stream.Context(), s.queryServiceClient, req.GetProfile().GetPools())
	if err != nil {
		log.Printf("Failed to query tickets for the given pools, got %s", err.Error())
		return err
	}

	// log.Printf("Pool Tickets: %v", poolTickets)
	// Generate proposals.
	proposals, err := makeMatches(req.GetProfile(), poolTickets)
	if err != nil {
		log.Printf("Failed to generate matches, got %s", err.Error())
		return err
	}
	if len(proposals) > 0 {
		log.Printf("Generating proposals for function %v", req.GetProfile().GetName())
		log.Printf("Streaming %d proposals to Open Match", len(proposals))

		// Stream the generated proposals back to Open Match.
		for _, proposal := range proposals {
			if err := stream.Send(&pb.RunResponse{Proposal: proposal}); err != nil {
				log.Printf("Failed to stream proposals to Open Match, got %s", err.Error())
				return err
			}
			// log.Printf("Proposal %v", proposal)
		}
	}

	return nil
}

func makeMatches(p *pb.MatchProfile, poolTickets map[string][]*pb.Ticket) ([]*pb.Match, error) {
	var matches []*pb.Match
	count := 0
	unsortedMatchTickets := []*pb.Ticket{}
	for {
		insufficientTickets := false
		// matchTickets := []*pb.Ticket{}
		for pool, tickets := range poolTickets {
			if len(tickets) < TicketsPerPoolPerMatch {
				// This pool is completely drained out. Stop creating matches.
				insufficientTickets = true
				break
			}

			// Remove the Tickets from this pool and add to the match proposal.
			unsortedMatchTickets = append(unsortedMatchTickets, tickets[0:TicketsPerPoolPerMatch]...)
			poolTickets[pool] = tickets[TicketsPerPoolPerMatch:]
		}

		if insufficientTickets {
			break
		}

		count++
	}
	totalLatency := 0.0
	if len(unsortedMatchTickets) > 0 {
		sort.Slice(unsortedMatchTickets, func(i, j int) bool {
			return unsortedMatchTickets[i].SearchFields.DoubleArgs["latency-"+unsortedMatchTickets[i].SearchFields.StringArgs["region"]] < unsortedMatchTickets[j].SearchFields.DoubleArgs["latency-"+unsortedMatchTickets[j].SearchFields.StringArgs["region"]]
		})

		for matchIndex := 0; matchIndex < count; matchIndex++ {
			matchTickets := []*pb.Ticket{}
			for ticketIndex := 0; ticketIndex < TicketsPerPoolPerMatch; ticketIndex++ {
				currentTicket := unsortedMatchTickets[TicketsPerPoolPerMatch*matchIndex+ticketIndex]
				// log.Printf("currentTicket: %s", currentTicket)
				// log.Printf(p.GetName()[20:37]+": %g", currentTicket.SearchFields.DoubleArgs[p.GetName()[20:37]])
				totalLatency = totalLatency + currentTicket.SearchFields.DoubleArgs[p.GetName()[20:37]]
				matchTickets = append(matchTickets, currentTicket)
			}

			matchScore := 1000 / (totalLatency / float64(TicketsPerPoolPerMatch))
			evaluationInput, err := anypb.New(&pb.DefaultEvaluationCriteria{
				Score: matchScore,
			})

			if err != nil {
				log.Printf("Failed to marshal DefaultEvaluationCriteria, got %v.", err)
				return nil, fmt.Errorf("Failed to marshal DefaultEvaluationCriteria, got %w", err)
			}

			matches = append(matches, &pb.Match{
				MatchId:       fmt.Sprintf("profile-%v-time-%v-%v", p.GetName(), time.Now().Format("2006-01-02T15:04:05.00"), matchIndex),
				MatchProfile:  p.GetName(),
				MatchFunction: matchName,
				Tickets:       matchTickets,
				Extensions: map[string]*anypb.Any{
					"evaluation_input": evaluationInput,
				},
			})

			// log.Printf("Match Tickets: %d %s", len(matchTickets), matchTickets)
			// log.Printf("Evaluation Input: %s", evaluationInput)
		}
	}

	// if matches != nil {
	// 	log.Printf("matches %s", matches)
	// }

	return matches, nil

}
