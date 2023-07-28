# SuperTuxKart client wrapper

This code implements a wrapper to call the SuperTuxKart client with the server/port returned by the [allocation](../allocation-client/) module that handles the communication with the Open Match Frontend.

```bash
Usage:
player -frontend FrontendAddress:Port -latencyUsEast1 int -latencyUsEast2 int -path /path/to/stk/binary
  -frontend string
    	Open Match Frontend Endpoint (default "localhost:50504")
  -latencyUsEast1 int
    	Latency to region us-east-1 (default 100)
  -latencyUsEast2 int
    	Latency to region us-east-2 (default 100)
  -path string
    	SuperTuxKart binary path (default "supertuxkart")
```