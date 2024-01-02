# SuperTuxKart client wrapper

This code implements a wrapper to call the SuperTuxKart client with the server/port returned by the [allocation](../allocation-client/) module that handles the communication with the Open Match Frontend. 

Get the TLS cert of the Frontend and run the player client:
```bash
kubectl get secret open-match-tls-server -n open-match -o jsonpath="{.data.public\.cert}" | base64 -d > public.cert
kubectl get secret open-match-tls-server -n open-match -o jsonpath="{.data.private\.key}" | base64 -d > private.key
kubectl get secret open-match-tls-rootca -n open-match -o jsonpath="{.data.public\.cert}" | base64 -d > publicCA.cert
go run main.go -frontend <global_accelerator_address>:50504 -region1 $REGION1 -latencyRegion1 10 -region2 $REGION2 -latencyRegion2 30  -path /path/to/stk/binary
```


