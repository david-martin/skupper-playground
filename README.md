# skupper-playground

## Prerequisites

Install skupper according to the [instructions](https://skupper.io/install/index.html).

Set up local kind clusters, initialise skupper & link the sites.

```bash
make local-setup
```

Attempt to curl the app API via the frontend app.
It should fail as the frontend cannot reach the backend service.
The error text should include something like `Name or service not known`

```bash
export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-1.kubeconfig
curl -X POST --data '{"name":"Test","text":"Hello"}' http://$(kubectl get svc frontend -o jsonpath="{.status.loadBalancer.ingress[0].ip}"):8080/api/hello
```

Attempt to expose the backend service over the skupper network.
It should fail because of the SkupperClusterPolicy.
The error text should look like `Error: Policy validation error: deployment/backend cannot be exposed`

```bash
export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-2.kubeconfig
skupper expose deployment/backend --port 8080
```

Update the SkupperClusterPolicy and attempt to expose the backend service again.
It should succeed this time.

```bash
export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-1.kubeconfig
kubectl apply -f ./config/examples/skupperclusterpolicy_2.yaml
export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-2.kubeconfig
kubectl apply -f ./config/examples/skupperclusterpolicy_2.yaml
skupper expose deployment/backend --port 8080
```

Attempt to curl the health endpoint of the frontend app again.
It should succeed this time.

```bash
export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-1.kubeconfig
curl http://$(kubectl get svc frontend -o jsonpath="{.status.loadBalancer.ingress[0].ip}"):8080/api/health
```
