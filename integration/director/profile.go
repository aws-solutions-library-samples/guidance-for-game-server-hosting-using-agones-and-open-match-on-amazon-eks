// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

package main

import (
	"fmt"
	"math/rand"
	"strconv"
	"strings"
	"time"

	"open-match.dev/open-match/pkg/pb"
)

// Generates profiles based on player latency for the Director.
func generateProfiles(regions []string, ranges []string) []*pb.MatchProfile {
	var profiles []*pb.MatchProfile

	// We could add extra criteria for the profile, like World name, region and skills, in this case we will use latency from the client to each region

	// worlds := []string{"Dune", "Nova", "Pandora", "Orion"}
	// regions := []string{"us-east-1", "us-east-2", "us-west-1", "us-west-2"}

	// skillLevels := []*pb.DoubleRangeFilter{
	// 	{DoubleArg: "skill", Min: 0, Max: 10},
	// 	{DoubleArg: "skill", Min: 10, Max: 100},
	// 	{DoubleArg: "skill", Min: 100, Max: 1000},
	// }

	latency := []*pb.DoubleRangeFilter{}

	for _, region := range regions {
		for _, rang := range ranges {
			lower, _ := strconv.ParseFloat(strings.Split(rang, "-")[0], 64)
			upper, _ := strconv.ParseFloat(strings.Split(rang, "-")[1], 64)
			latency = append(latency, &pb.DoubleRangeFilter{DoubleArg: "latency-" + region, Min: lower, Max: upper})
			fmt.Printf("Region: %s Min: %f Max: %f\n", region, lower, upper)
		}
	}
	for _, regionLatency := range latency {
		profile := &pb.MatchProfile{
			Name: fmt.Sprintf("profile_%v", regionLatency),
			Pools: []*pb.Pool{
				{
					Name: "pool_mode_" + fmt.Sprintf("%v", regionLatency),
					TagPresentFilters: []*pb.TagPresentFilter{
						{Tag: "mode.session"},
					},
					StringEqualsFilters: []*pb.StringEqualsFilter{
						//  Possible extra string criteria
						//  {StringArg: "world", Value: world},
						// 	{StringArg: "region", Value: region},
					},
					DoubleRangeFilters: []*pb.DoubleRangeFilter{
						regionLatency,
						// Possible extra numerical criteria
						// DoubleRangeFilterFromSlice(skillLevels),
					},
				},
			},
		}

		profiles = append(profiles, profile)
	}
	return profiles
}

func TagFromStringSlice(tags []string) string {
	rand.Seed(time.Now().UTC().UnixNano())
	randomIndex := rand.Intn(len(tags))

	return tags[randomIndex]
}

func DoubleRangeFilterFromSlice(tags []*pb.DoubleRangeFilter) *pb.DoubleRangeFilter {
	rand.Seed(time.Now().UTC().UnixNano())
	randomIndex := rand.Intn(len(tags))

	return tags[randomIndex]
}
