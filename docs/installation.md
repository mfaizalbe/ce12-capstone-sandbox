# Helm stage installs these charts:

aws-load-balancer-controller
external-dns
prometheus (kube-prometheus-stack)
loki
opentelemetry-operator
CRDs installed as part of Helm stage and hooks

From your current flow, these CRD groups are installed before/during Helm:

Gateway API + AWS Gateway CRDs from helm/crds (via ALB presync hook in Helmfile)
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
grpcroutes.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
referencegrants.gateway.networking.k8s.io
listenerruleconfigurations.gateway.k8s.aws
loadbalancerconfigurations.gateway.k8s.aws
targetgroupconfigurations.gateway.k8s.aws
AWS Load Balancer Controller CRDs (chart-managed)
ingressclassparams.elbv2.k8s.aws
targetgroupbindings.elbv2.k8s.aws
Prometheus Operator CRDs (via prometheus presync hook from chart CRDs)
alertmanagerconfigs.monitoring.coreos.com
alertmanagers.monitoring.coreos.com
podmonitors.monitoring.coreos.com
probes.monitoring.coreos.com
prometheusagents.monitoring.coreos.com
prometheuses.monitoring.coreos.com
prometheusrules.monitoring.coreos.com
scrapeconfigs.monitoring.coreos.com
servicemonitors.monitoring.coreos.com
thanosrulers.monitoring.coreos.com
OpenTelemetry Operator CRDs (chart resources)
instrumentations.opentelemetry.io
opampbridges.opentelemetry.io
opentelemetrycollectors.opentelemetry.io
targetallocators.opentelemetry.io
What is left for manifests stage

# Presync Hooks

presync hook is a Helmfile lifecycle hook that runs before Helm installs/upgrades a specific release.

In your file helmfile.yaml.gotmpl, it is used to enforce prerequisites:

For aws-load-balancer-controller
presync runs kubectl apply -k crds
Purpose: install Gateway/API CRDs before chart resources that depend on them
For prometheus
presync runs helm show crds ... | kubectl apply --server-side -f -
Purpose: install monitoring.coreos.com CRDs before kube-prometheus-stack resources (PrometheusRule, ServiceMonitor, etc.)
So conceptually:

needs controls release-to-release order.
presync prepares dependencies for a release right before that release runs.
It is triggered by Helmfile sync, not by Kustomize directly.

# Kustomize

When you run the Kustomize manifests apply, it mainly installs app/platform resources, not new CRD definitions (in your current split). That includes:

Application namespaces, deployments, services, configmaps, secrets
carts, catalog, checkout, orders, ui, load-gen, fluentbit, grafana route pieces, etc.
Gateway/GatewayClass/HTTPRoute/TargetGroup config custom resources
these rely on CRDs already installed in Helm stage/hooks.
ADOT custom resources
notably OpenTelemetryCollector objects in manifests/adot (CRD already present from opentelemetry-operator chart).
So practical summary:

Helm stage = controllers/operators + required CRDs.
Manifests stage = workload resources and custom resources that depend on those CRDs/controllers.
