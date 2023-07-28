sleep 30; kubectl get namespace $1 && kubectl get namespace $1 -o json | jq 'del(.spec.finalizers[0])' | kubectl replace --raw "/api/v1/namespaces/$1/finalize" -f -

