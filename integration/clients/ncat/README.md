# ncat client

This code implements a simple chat client that communicates with the [ncat-server](../../ncat-server/) game servers deployed to our clusters. It    calls the [allocation](../allocation-client/) module that handles the communication with the Frontend, connects to the game server address returned, and runs a loop to exchange messages with the other clients connected to the ncat-server. 
```bash
Usage:
player -frontend FrontendAddress:Port -latencyUsEast1 int -latencyUsEast2 int
  -frontend string
    	Open Match Frontend Endpoint (default "localhost:50504")
  -latencyUsEast1 int
    	Latency to region us-east-1 (default 100)
  -latencyUsEast2 int
    	Latency to region us-east-2 (default 100)
````

![](./ncat-sample.png)*Sample screen*