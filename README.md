# skupper-playground

## Prerequisites

Install skupper according to the [instructions](https://skupper.io/install/index.html).

## Cluster & Skupper Site setup

Set up local kind clusters, initialise skupper & link the sites.

```bash
make local-setup
```

The skupper console is deployed to the west site.
The url is logged out when you run the below:

```bash
export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-1.kubeconfig
skupper status
```

The password for the `admin` user can be retrieved from a secret:

```bash
export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-1.kubeconfig
kubectl get secret skupper-console-users -o jsonpath="{.data.admin}" | base64 --decode
```

## SkupperClusterPolicy example

Deploy the frontend and backend apps

```bash
export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-1.kubeconfig
kubectl create deployment frontend --image quay.io/skupper/hello-world-frontend
kubectl expose deployment/frontend --port 8080 --type LoadBalancer
export KUBECONFIG=./tmp/kubeconfigs/skupper-cluster-2.kubeconfig
kubectl create deployment backend --image quay.io/skupper/hello-world-backend --replicas 3
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
