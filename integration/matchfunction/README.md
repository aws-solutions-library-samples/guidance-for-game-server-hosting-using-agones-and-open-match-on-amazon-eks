## Name
Guidance for Game Server Hosting on Amazon EKS with Agones and Open Match - Match Function
# Description
This module implements a matchmaking function for OpenMatch.
## Current State
This MatchFunction receives MatchProfiles from the Director, based on latencies to 4 regions, get tickets from query service, sorts them by latency and creates matches with ajdacent latency players.
## Testing and monitoring
The Match Function receives profile requests from the Open-Match backend provided by the [Director](../director/) and fetches the pools from the Open-Match query service. The execution flow can be inspected through the logs of the director, mmf (in the agones-openmatch namespace) and query (in the open-match namespace) pods.
