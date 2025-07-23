# kind-submariner

## Create Cluster

Create the broker cluster:

```bash
kind create cluster --name broker --config broker/kind-config.yml
```

- Make sure the client cluster is accessible through the internet and that the API server has a public IP address. Check out the broker kind config file in `broker/kind-config.yml`.
- We assume each client cluster is deployed on a different machine. The API server of each machine 
should be visible to others, as required by Submariner. NAT traversal for clusters behind a firewall is not considered. If you use kind, port mapping should be applied to map port `4500` of the host machine to the node running gateway. See `cluster1/kind-config.yml` for en exampel setup.

Make sure port **6443 (TCP)** and **4500 (UDP)** are open for each cluster.

## Submariner Configuration

### Broker Cluster

```bash
helm --kube-context kind-broker repo add submariner-latest \
  https://submariner-io.github.io/submariner-charts/charts 

export CONTEX=kind-broker
helm install --create-namespace \
             --namespace submariner-k8s-broker \
             --kube-context ${CONTEXT} \
             submariner-k8s-broker submariner-latest/submariner-k8s-broker
```

Then run `broker/var-export.sh` to generate the env variables. The file 
`broker/var-source.env` is generated that can be sourced with all required 
env variables when setting up other client clusters.

```bash
./broker/var-export.sh
# Then check ./broker/var-source.env file to validate the variables

# IMPORTANT:
#    -> Ensure the IP address is set to the public IP address of the 
#       broker cluster.

# Copy this file to all other cluster machines
```

- You need to set your public IP in the `var-source.env` instead of broker local kind API server address (e.g. `172.18.0.5`).


### Client Clusters

For each cluster, repeat the following instructions:

The following instructions is for `cluster1`, and should be repeated for all other clusters.

```bash
kind create cluster --name cluster1 --config cluster1/kind-config.yml
```

Copy the env-source.env file to this cluster machine, then:

```bash

# Make sure the kubeconfig file uses the right IP for the API server
# instead of 0.0.0.0
sed -i "s/0\.0\.0\.0/$(curl -s ifconfig.io)/g" ~/.kube/config

c=cluster1
# Ensure path are correct, then source env variables:
source broker/var-source.env
source ${c}/var-cluster.env

# A safety check to ensure variables are set
if [[ -z "$SUBMARINER_BROKER_TOKEN" || -z "$CLUSTER_CIDR" ]]; then
  echo "Variables are not set for $c".
  break
fi
  
# Add the helm repo:
helm --kube-context $CONTEXT repo add submariner-latest \
  https://submariner-io.github.io/submariner-charts/charts 


# Make sure one node is labled as gateway:
kubectl label --context=$CONTEXT node $c-control-plane submariner.io/gateway="true"

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
      --set debug=true \
      --kube-context $CONTEXT
```

Check out the status of pods, and look for any errors. If there is no error, after a few mintues,
any pod in one cluster should be able to ping other pods in other clusters.