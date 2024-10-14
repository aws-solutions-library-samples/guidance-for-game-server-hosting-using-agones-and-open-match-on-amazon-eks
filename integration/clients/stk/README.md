# SuperTuxKart client wrapper

This code implements a wrapper to call the SuperTuxKart client with the server/port returned by the [allocation](../allocation-client/) module that handles the communication with the Open Match Frontend. 

To test this server, we need to download the client from https://github.com/supertuxkart/stk-code/releases and install it to our system, taking note of the location of the STK binary to use in our test.

## Deploy the game server fleets

1. Remove ncat servers
If there were ncat servers deployed to the clusters following the [main instructions](../../../README.md#build-and-deploy-the-game-server-fleets), remove them from the clusters.
```bash
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER1})
kubectl delete fleets -n gameservers --all
kubectl config use-context $(kubectl config get-contexts -o=name | grep ${CLUSTER2})
kubectl delete fleets -n gameservers --all
```

2. Deploy STK servers
For x86-based instances:
```bash
sh scripts/deploy-stk-fleets.sh ${CLUSTER1} ${REGION1} ${CLUSTER2} ${REGION2} amd64
```

For arm-based instances:
```bash
sh scripts/deploy-stk-fleets.sh ${CLUSTER1} ${REGION1} ${CLUSTER2} ${REGION2} arm64
```

### Test the stk server
1. Go to the `integration/clients/stk`
```bash
cd integration/clients/stk
```
2. Get the TLS cert of the Frontend 
```bash
kubectl get secret open-match-tls-server -n open-match -o jsonpath="{.data.public\.cert}" | base64 -d > public.cert
kubectl get secret open-match-tls-server -n open-match -o jsonpath="{.data.private\.key}" | base64 -d > private.key
kubectl get secret open-match-tls-rootca -n open-match -o jsonpath="{.data.public\.cert}" | base64 -d > publicCA.cert
```
3. Run the player client. Here we'll use the value of `global_accelerator_address` from the Terraform deployment. Remember to adjust our regions and use the location of the installed STK binary:
```bash
REGION1=us-east-1
REGION2=us-east-2
go run main.go -frontend <global_accelerator_address>:50504 -region1 $REGION1 -latencyRegion1 10 -region2 $REGION2 -latencyRegion2 30  -path /path/to/stk/binary
```
3. In three other terminal windows, type the commands from the steps **(1.)** and **(3.)** above.
Be aware that this will run 4 instances of the SuperTuxKart client game (like we did with our terminal clients in the [ncat example](../../../README.md#test-the-ncat-server)), so it can be a bit demanding to run it in a single computer. One alternative is to clone this project on 3 other computers and run the steps above on them. From this point on, the server behavior should be the same as the observed in the ncat example.