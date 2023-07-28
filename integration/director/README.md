## Name
Guidance for Game Server Hosting on Amazon EKS with Agones and Open Match - Director

# Description

This module implements a Director for OpenMatch. The Director fetches Matches from Open Match for a set of MatchProfiles.

**Disclaimer:**
- *We are currently at the development stage of the project and the steps described below are experimental. Please do not use them for production workloads.*
- The steps below have been tested with EKS 1.22
## Current State ##
The Director submit MatchProfiles with latency requirements to the [Match Function](../matchfunction), and after receiving the Match Proposals, it sends an allocation request to the Agones Allocator service. After receiving the allocattion from Agones, the Director returns the game server details to Open Match Frontend service, like in the logs below:
```
2023/02/20 21:13:11 Generated 1 matches for profile profile_double_arg:"latency-us-east-2"  max:49  min:25
2023/02/20 21:13:12 Gameserver: ec2-3-22-130-7.us-east-2.compute.amazonaws.com
2023/02/20 21:13:12 Port: 7851
2023/02/20 21:13:12 Assigned server ec2-3-22-130-7.us-east-2.compute.amazonaws.com:7851 to match profile-profile_double_arg:"latency-us-east-2"  max:49  min:25-time-2023-02-20T21:13:11.24-0

```
## ToDo
- ~~Expand the ```assign``` function on [main.go](main.go) to integrate the Director with Agones Allocator (maybe using [Agones Allocator Client](https://github.com/FairwindsOps/agones-allocator-client)).~~ Done
## Using your own images

The examples on this repository use pre-built images stored in the `public.ecr.aws/mphauer/` registry. If you want to experiment changing the code and using your own image, follow the instructions.

1. Setup the docker registry to push/pull images

```bash
REGISTRY=XXXXXXXXXXXX.dkr.ecr.us-east-2.amazonaws.com
```

2. Create a pre-build image with needed modules 
```bash
docker build -f Dockerfile.pre -t go-mod-tidy-director .
```

3. Build the Match Function image.
```bash
docker build -t $REGISTRY/agones-openmatch-director .
```

4. Push the Match Function image to the configured Registry.
```bash
  aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin XXXXXXXXXXXX.dkr.ecr.us-east-2.amazonaws.com
  
  docker push $REGISTRY/agones-openmatch-director:latest
```

5. Change the `image:` field in the [director.yaml](./director.yaml) file.

```
        image: XXXXXXXXXXXX.dkr.ecr.us-east-2.amazonaws.com/agones-openmatch-director:latest
```

6. Deploy the function to the agones-openmatch namespace.
```bash
    kubectl apply -f director.yaml
```

The step 2 above is used to speed up the build of the container, since `go mod tidy` can take a long time and is only needed when there is a change in the go modules. So, the first time we run steps 2 and 3, after that if we need to rebuild the container after a modification outside the scope of the go modules, we just run step 3.


## Testing and monitoring
The [Match Function](../matchfunction) receives profile requests from the Open-Match backend provided by the Director and fetches the pools from the Open-Match query service. The execution flow can be inspected through the logs of the director, mmf (in the agones-openmatch namespace) and query (in the open-match namespace) pods.
