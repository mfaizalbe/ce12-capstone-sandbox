# installation

```bash
helm upgrade kubecost kubecost \
--repo https://kubecost.github.io/kubecost \
--set global.clusterId=retail-store-grp5 \
--set kubecostProductConfigs.prometheus.url=http://prometheus-kube-prometheus-prometheus.monitoring:9090 \
--set persistence.enabled=false \
--set localStore.persistence.enabled=false \
--set cloudCost.persistence.enabled=false \
--set aggregator.persistence.enabled=false \
--set aggregator.resources.requests.memory=1Gi \
--set aggregator.resources.limits.memory=2Gi \
--namespace kubecost --create-namespace
```

Wait for pods to be Ready:

```bash
kubectl get pods --namespace kubecost
```

Enable port-forwarding:

```bash
kubectl port-forward --namespace kubecost deployment/kubecost-frontend 9090
```

Updating Kubecost

```bash
helm repo add kubecost https://kubecost.github.io/kubecost/ && \
helm repo update && \
helm upgrade kubecost kubecost/kubecost -n kubecost
```

Deleting Kubecost

```bash
helm uninstall kubecost -n kubecost
```
