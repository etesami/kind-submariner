#!/bin/bash

export BROKER_NS=submariner-k8s-broker

export SUBMARINER_BROKER_CA=$(kubectl -n "${BROKER_NS}" get secrets --context kind-b1 \
    -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='${BROKER_NS}-client')].data['ca\.crt']}")
export SUBMARINER_BROKER_TOKEN=$(kubectl -n "${BROKER_NS}" get secrets --context kind-b1  \
    -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='${BROKER_NS}-client')].data.token}" \
       | base64 --decode)
export SUBMARINER_BROKER_URL=$(kubectl -n default get endpoints kubernetes --context kind-b1 \
    -o jsonpath="{.subsets[0].addresses[0].ip}:{.subsets[0].ports[?(@.name=='https')].port}")

export SUBMARINER_PSK=$(LC_CTYPE=C tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 64 | head -n 1)

echo "export BROKER_NS=submariner-k8s-broker" > var-source.env
echo "export SUBMARINER_BROKER_CA=${SUBMARINER_BROKER_CA}" >> var-source.env
echo "export SUBMARINER_BROKER_TOKEN=${SUBMARINER_BROKER_TOKEN}" >> var-source.env
echo "export SUBMARINER_BROKER_URL=${SUBMARINER_BROKER_URL}" >> var-source.env
echo "export SUBMARINER_NS=submariner-operator" >> var-source.env
echo "export SUBMARINER_PSK=${SUBMARINER_PSK}" >> var-source.env