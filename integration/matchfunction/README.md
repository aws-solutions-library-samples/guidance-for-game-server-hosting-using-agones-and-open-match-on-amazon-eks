## Name
Guidance for Game Server Hosting on Amazon EKS with Agones and Open Match - Match Function

# Description

This module implements a matchmaking function for OpenMatch.

**Disclaimer:**
- *We are currently at the development stage of the project and the steps described below are experimental. Please do not use them for production workloads.*
- The steps below have been tested with EKS 1.22

## Current State
This MatchFunction receives MatchProfiles from the Director, based on latencies to 4 regions, get tickets from query service, sorts them by latency and creates matches with ajdacent latency players.
## ToDo
- Enhance the filter
- Use the Evaluator in case of overlapping matches
## Using your own images

The examples on this repository use pre-built images stored in the `public.ecr.aws/mphauer/` registry. If you want to experiment changing the code and using your own image, follow the instructions.

1. Setup the docker registry to pull images

```bash
REGISTRY=XXXXXXXXXXXX.dkr.ecr.us-east-2.amazonaws.com
```
2. Create a pre-build image with needed modules 
```bash
docker build -f Dockerfile.pre -t go-mod-tidy-matchfunction .
```

3. Build the Match Function image
```bash
docker build -t $REGISTRY/agones-openmatch-matchfunction .
```

4. Push the Match Function image to the configured Registry.
```bash
  aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin XXXXXXXXXXXX.dkr.ecr.us-east-2.amazonaws.com
  
  docker push $REGISTRY/agones-openmatch-matchfunction:latest
```

5. Change the `image:` field in the [matchfunction.yaml](./matchfunction.yaml) file.

```
        image: XXXXXXXXXXXX.dkr.ecr.us-east-2.amazonaws.com/agones-openmatch-matchfunction:latest
```

6. Deploy the function to the agones-openmatch namespace
```bash
    kubectl apply -f matchfunction.yaml
```

The step 2 above is used to speed up the build of the container, since `go mod tidy` can take a long time and is only needed when there is a change in the go modules. So, the first time we run steps 2 and 3, after that if we need to rebuild the container after a modification outside the scope of the go modules, we just run step 3.

## Testing and monitoring
The Match Function receives profile requests from the Open-Match backend provided by the [Director](../director/) and fetches the pools from the Open-Match query service. The execution flow can be inspected through the logs of the director, mmf (in the agones-openmatch namespace) and query (in the open-match namespace) pods.
