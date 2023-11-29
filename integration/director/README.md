## Name
Guidance for Game Server Hosting on Amazon EKS with Agones and Open Match - Director
# Description
This module implements a Director for OpenMatch. The Director fetches Matches from Open Match for a set of MatchProfiles.
## Current State ##
The Director submit MatchProfiles with latency requirements to the [Match Function](../matchfunction), and after receiving the Match Proposals, it sends an allocation request to the Agones Allocator service. After receiving the allocattion from Agones, the Director returns the game server details to Open Match Frontend service, like in the logs below:
```
2023/02/20 21:13:11 Generated 1 matches for profile profile_double_arg:"latency-us-east-2"  max:49  min:25
2023/02/20 21:13:12 Gameserver: ec2-3-22-130-7.us-east-2.compute.amazonaws.com
2023/02/20 21:13:12 Port: 7851
2023/02/20 21:13:12 Assigned server ec2-3-22-130-7.us-east-2.compute.amazonaws.com:7851 to match profile-profile_double_arg:"latency-us-east-2"  max:49  min:25-time-2023-02-20T21:13:11.24-0

```
## Testing and monitoring
The [Match Function](../matchfunction) receives profile requests from the Open-Match backend provided by the Director and fetches the pools from the Open-Match query service. The execution flow can be inspected through the logs of the director, mmf (in the agones-openmatch namespace) and query (in the open-match namespace) pods.
