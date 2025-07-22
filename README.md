# kind-submariner

## Create Cluster

```bash
kind create cluster --name broker --config broker/kind-config.yml
```

## Submariner Configuration

### Broker Cluster

```bash
helm --kube-context kind-broker repo add submariner-latest \
  https://submariner-io.github.io/submariner-charts/charts 

helm install --create-namespace \
             --namespace submariner-k8s-broker \
             --kube-context kind-broker \
             submariner-k8s-broker submariner-latest/submariner-k8s-broker \          
```

Then run `broker/var-export.sh` to generate the env variables stored in `broker/var-source.env` and are needed for other clusters.

```bash
./broker/var-export.sh
# Then check ./broker/var-source.env file to validate the variables
```

### Client Clusters

For each cluster, repeat the following instructions:

- Make sure the client cluster is accessible through the internet and that the API server has a public IP address.
- We assume each client cluster is deployed on a different machine. The API server of each machine should be visible to others, as required by Submariner. NAT traversal for clusters behind a firewall is not considered.

First copy the env-source.env file to each cluster:

```bash
clusters="cluster1 cluster2 cluster3"
for c in clusters; do scp broker/var-source.env $c:~/kind-submariner/$c/; done
```

Then in each machine run:

```bash

CLUSTERS="cluster1 cluster2 cluster3"


for c in $CLUSTERS; do
  source broker/var-source.env
  source ${c}/var-cluster.env

  # a safety check to ensure variables are set
  if [[ -z "$SUBMARINER_BROKER_TOKEN" || -z "$CLUSTER_CIDR" ]]; then
    echo "Variables are not set for $c".
    break
  fi
  
  helm --kube-context $CONTEXT repo add submariner-latest \
    https://submariner-io.github.io/submariner-charts/charts 
  
  helm install submariner-operator submariner-latest/submariner-operator \
        --create-namespace \
        --namespace "${SUBMARINER_NS}" \
        --set ipsec.psk="${SUBMARINER_PSK}" \
        --set broker.server="${SUBMARINER_BROKER_URL}" \
        --set broker.token="${SUBMARINER_BROKER_TOKEN}" \
        --set broker.namespace="${BROKER_NS}" \
        --set broker.ca="${SUBMARINER_BROKER_CA}" \
        --set submariner.serviceDiscovery=false \
        --set submariner.cableDriver=wireguard \
        --set submariner.clusterId="${CLUSTER_ID}" \
        --set submariner.clusterCidr="${CLUSTER_CIDR}" \
        --set submariner.serviceCidr="${SERVICE_CIDR}" \
        --set submariner.natEnabled="true" \
        --set serviceAccounts.lighthouseAgent.create=true \
        --set serviceAccounts.lighthouseCoreDns.create=true \
        --kube-context $CONTEXT
```