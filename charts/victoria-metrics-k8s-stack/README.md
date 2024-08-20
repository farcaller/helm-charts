# Helm Chart For Victoria Metrics kubernetes monitoring stack.

![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)  ![Version: 0.25.2](https://img.shields.io/badge/Version-0.25.2-informational?style=flat-square)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/victoriametrics)](https://artifacthub.io/packages/helm/victoriametrics/victoria-metrics-k8s-stack)

Kubernetes monitoring on VictoriaMetrics stack. Includes VictoriaMetrics Operator, Grafana dashboards, ServiceScrapes and VMRules

* [Overview](#Overview)
* [Configuration](#Configuration)
* [Prerequisites](#Prerequisites)
* [Dependencies](#Dependencies)
* [Quick Start](#How-to-install)
* [Uninstall](#How-to-uninstall)
* [Version Upgrade](#Upgrade-guide)
* [Troubleshooting](#Troubleshooting)
* [Values](#Parameters)

## Overview
This chart is an All-in-one solution to start monitoring kubernetes cluster.
It installs multiple dependency charts like [grafana](https://github.com/grafana/helm-charts/tree/main/charts/grafana), [node-exporter](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-node-exporter), [kube-state-metrics](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics) and [victoria-metrics-operator](https://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-metrics-operator).
Also it installs Custom Resources like [VMSingle](https://docs.victoriametrics.com/operator/quick-start.html#vmsingle), [VMCluster](https://docs.victoriametrics.com/operator/quick-start.html#vmcluster), [VMAgent](https://docs.victoriametrics.com/operator/quick-start.html#vmagent), [VMAlert](https://docs.victoriametrics.com/operator/quick-start.html#vmalert).

By default, the operator [converts all existing prometheus-operator API objects](https://docs.victoriametrics.com/operator/quick-start.html#migration-from-prometheus-operator-objects) into corresponding VictoriaMetrics Operator objects.

To enable metrics collection for kubernetes this chart installs multiple scrape configurations for kuberenetes components like kubelet and kube-proxy, etc. Metrics collection is done by [VMAgent](https://docs.victoriametrics.com/operator/quick-start.html#vmagent). So if want to ship metrics to external VictoriaMetrics database you can disable VMSingle installation by setting `vmsingle.enabled` to `false` and setting `vmagent.vmagentSpec.remoteWrite.url` to your external VictoriaMetrics database.

This chart also installs bunch of dashboards and recording rules from [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) project.

![Overview](img/k8s-stack-overview.png)

## Configuration

Configuration of this chart is done through helm values.

### Dependencies

Dependencies can be enabled or disabled by setting `enabled` to `true` or `false` in `values.yaml` file.

**!Important:** for dependency charts anything that you can find in values.yaml of dependency chart can be configured in this chart under key for that dependency. For example if you want to configure `grafana` you can find all possible configuration options in [values.yaml](https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml) and you should set them in values for this chart under grafana: key. For example if you want to configure `grafana.persistence.enabled` you should set it in values.yaml like this:
```yaml
#################################################
###              dependencies               #####
#################################################
# Grafana dependency chart configuration. For possible values refer to https://github.com/grafana/helm-charts/tree/main/charts/grafana#configuration
grafana:
  enabled: true
  persistence:
    type: pvc
    enabled: false
```

### VictoriaMetrics components

This chart installs multiple VictoriaMetrics components using Custom Resources that are managed by [victoria-metrics-operator](https://docs.victoriametrics.com/operator/design.html)
Each resource can be configured using `spec` of that resource from API docs of [victoria-metrics-operator](https://docs.victoriametrics.com/operator/api.html). For example if you want to configure `VMAgent` you can find all possible configuration options in [API docs](https://docs.victoriametrics.com/operator/api.html#vmagent) and you should set them in values for this chart under `vmagent.spec` key. For example if you want to configure `remoteWrite.url` you should set it in values.yaml like this:
```yaml
vmagent:
  spec:
    remoteWrite:
      - url: "https://insert.vmcluster.domain.com/insert/0/prometheus/api/v1/write"
```

### ArgoCD issues

When deploying K8s stack using ArgoCD without Cert Manager (`.Values.victoria-metrics-operator.admissionWebhooks.certManager.enabled: false`)
it will rerender operator's webhook certificates on each sync since Helm `lookup` function is not respected by ArgoCD.
To prevent this please update you K8s stack Application `spec.syncPolicy` and `spec.ignoreDifferences` with a following:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
...
spec:
  ...
  syncPolicy:
    syncOptions:
    # https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#respect-ignore-difference-configs
    # argocd must also ignore difference during apply stage
    # otherwise it ll silently override changes and cause a problem
    - RespectIgnoreDifferences=true
  ignoreDifferences:
    - group: ""
      kind: Secret
      name: <fullname>-validation
      namespace: kube-system
      jsonPointers:
        - /data
    - group: admissionregistration.k8s.io
      kind: ValidatingWebhookConfiguration
      name: <fullname>-admission
      jqPathExpressions:
      - '.webhooks[]?.clientConfig.caBundle'
```
where `<fullname>` is output of `{{ include "vm-operator.fullname" }}` for your setup

### Rules and dashboards

This chart by default install multiple dashboards and recording rules from [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus)
you can disable dashboards with `defaultDashboardsEnabled: false` and `experimentalDashboardsEnabled: false`
and rules can be configured under `defaultRules`

### Prometheus scrape configs
This chart installs multiple scrape configurations for kubernetes monitoring. They are configured under `#ServiceMonitors` section in `values.yaml` file. For example if you want to configure scrape config for `kubelet` you should set it in values.yaml like this:
```yaml
kubelet:
  enabled: true

  # -- Enable scraping /metrics/cadvisor from kubelet's service
  cadvisor: true
  # -- Enable scraping /metrics/probes from kubelet's service
  probes: true
  # spec for VMNodeScrape crd
  # https://docs.victoriametrics.com/operator/api.html#vmnodescrapespec
  spec:
    interval: "30s"
```

## Prerequisites

* Install the follow packages: ``git``, ``kubectl``, ``helm``, ``helm-docs``. See this [tutorial](../../REQUIREMENTS.md).

* Add dependency chart repositories

```console
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

* PV support on underlying infrastructure.

## How to install

Access a Kubernetes cluster.

Add a chart helm repository with follow commands:

```console
helm repo add vm https://victoriametrics.github.io/helm-charts/

helm repo update
```

List versions of ``vm/victoria-metrics-k8s-stack`` chart available to installation:

```console
helm search repo vm/victoria-metrics-k8s-stack -l
```

Export default values of ``victoria-metrics-k8s-stack`` chart to file ``values.yaml``:

```console
helm show values vm/victoria-metrics-k8s-stack > values.yaml
```

Change the values according to the need of the environment in ``values.yaml`` file.

Test the installation with command:

```console
helm install [RELEASE_NAME] vm/victoria-metrics-k8s-stack -f values.yaml -n NAMESPACE --debug --dry-run
```

Install chart with command:

```console
helm install [RELEASE_NAME] vm/victoria-metrics-k8s-stack -f values.yaml -n NAMESPACE
```

Get the pods lists by running this commands:

```console
kubectl get pods -A | grep 'victoria-metrics'
```

### Install locally (Minikube)

To run VictoriaMetrics stack locally it's possible to use [Minikube](https://github.com/kubernetes/minikube). To avoid dashboards and alert rules issues please follow the steps below:

Run Minikube cluster

```
minikube start --container-runtime=containerd --extra-config=scheduler.bind-address=0.0.0.0 --extra-config=controller-manager.bind-address=0.0.0.0
```

Install helm chart

```
helm install [RELEASE_NAME] vm/victoria-metrics-k8s-stack -f values.yaml -f values.minikube.yaml -n NAMESPACE --debug --dry-run
```

## How to uninstall

Remove application with command.

```console
helm uninstall [RELEASE_NAME] -n NAMESPACE
```
This removes all the Kubernetes components associated with the chart and deletes the release.

_See [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) for command documentation._

CRDs created by this chart are not removed by default and should be manually cleaned up:

```console
kubectl get crd | grep victoriametrics.com | awk '{print $1 }' | xargs -i kubectl delete crd {}
```

## Troubleshooting

- If you cannot install helm chart with error `configmap already exist`. It could happen because of name collisions, if you set too long release name.
  Kubernetes by default, allows only 63 symbols at resource names and all resource names are trimmed by helm to 63 symbols.
  To mitigate it, use shorter name for helm chart release name, like:
```bash
# stack - is short enough
helm upgrade -i stack vm/victoria-metrics-k8s-stack
```
  Or use override for helm chart release name:
```bash
helm upgrade -i some-very-long-name vm/victoria-metrics-k8s-stack --set fullnameOverride=stack
```

## Upgrade guide

Usually, helm upgrade doesn't requires manual actions. Just execute command:

```console
$ helm upgrade [RELEASE_NAME] vm/victoria-metrics-k8s-stack
```

But release with CRD update can only be patched manually with kubectl.
Since helm does not perform a CRD update, we recommend that you always perform this when updating the helm-charts version:

```console
# 1. check the changes in CRD
$ helm show crds vm/victoria-metrics-k8s-stack --version [YOUR_CHART_VERSION] | kubectl diff -f -

# 2. apply the changes (update CRD)
$ helm show crds vm/victoria-metrics-k8s-stack --version [YOUR_CHART_VERSION] | kubectl apply -f - --server-side
```

All other manual actions upgrades listed below:

### Upgrade to 0.13.0

- node-exporter starting from version 4.0.0 is using the Kubernetes recommended labels. Therefore you have to delete the daemonset before you upgrade.

```bash
kubectl delete daemonset -l app=prometheus-node-exporter
```
- scrape configuration for kubernetes components was moved from `vmServiceScrape.spec` section to `spec` section. If you previously modified scrape configuration you need to update your `values.yaml`

- `grafana.defaultDashboardsEnabled` was renamed to `defaultDashboardsEnabled` (moved to top level). You may need to update it in your `values.yaml`

### Upgrade to 0.6.0

 All `CRD` must be update to the lastest version with command:

```bash
kubectl apply -f https://raw.githubusercontent.com/VictoriaMetrics/helm-charts/master/charts/victoria-metrics-k8s-stack/crds/crd.yaml

```

### Upgrade to 0.4.0

 All `CRD` must be update to `v1` version with command:

```bash
kubectl apply -f https://raw.githubusercontent.com/VictoriaMetrics/helm-charts/master/charts/victoria-metrics-k8s-stack/crds/crd.yaml

```

### Upgrade from 0.2.8 to 0.2.9

 Update `VMAgent` crd

command:
```bash
kubectl apply -f https://raw.githubusercontent.com/VictoriaMetrics/operator/v0.16.0/config/crd/bases/operator.victoriametrics.com_vmagents.yaml
```

 ### Upgrade from 0.2.5 to 0.2.6

New CRD added to operator - `VMUser` and `VMAuth`, new fields added to exist crd.
Manual commands:
```bash
kubectl apply -f https://raw.githubusercontent.com/VictoriaMetrics/operator/v0.15.0/config/crd/bases/operator.victoriametrics.com_vmusers.yaml
kubectl apply -f https://raw.githubusercontent.com/VictoriaMetrics/operator/v0.15.0/config/crd/bases/operator.victoriametrics.com_vmauths.yaml
kubectl apply -f https://raw.githubusercontent.com/VictoriaMetrics/operator/v0.15.0/config/crd/bases/operator.victoriametrics.com_vmalerts.yaml
kubectl apply -f https://raw.githubusercontent.com/VictoriaMetrics/operator/v0.15.0/config/crd/bases/operator.victoriametrics.com_vmagents.yaml
kubectl apply -f https://raw.githubusercontent.com/VictoriaMetrics/operator/v0.15.0/config/crd/bases/operator.victoriametrics.com_vmsingles.yaml
kubectl apply -f https://raw.githubusercontent.com/VictoriaMetrics/operator/v0.15.0/config/crd/bases/operator.victoriametrics.com_vmclusters.yaml
```

## Documentation of Helm Chart

Install ``helm-docs`` following the instructions on this [tutorial](../../REQUIREMENTS.md).

Generate docs with ``helm-docs`` command.

```bash
cd charts/victoria-metrics-k8s-stack

helm-docs
```

The markdown generation is entirely go template driven. The tool parses metadata from charts and generates a number of sub-templates that can be referenced in a template file (by default ``README.md.gotmpl``). If no template file is provided, the tool has a default internal template that will generate a reasonably formatted README.

## Parameters

The following tables lists the configurable parameters of the chart and their default values.

Change the values according to the need of the environment in ``victoria-metrics-k8s-stack/values.yaml`` file.

<table>
	<thead>
		<th>Key</th>
		<th>Type</th>
		<th>Default</th>
		<th>Description</th>
	</thead>
	<tbody>
		<tr>
			<td>additionalVictoriaMetricsMap</td>
			<td>string</td>
			<td><pre lang="">
null
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>alertmanager.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>alertmanager.config</td>
			<td>object</td>
			<td><pre lang="plaintext">
receivers:
    - name: blackhole
route:
    receiver: blackhole
templates:
    - /etc/vm/configs/**/*.tmpl
</pre>
</td>
			<td><p>alertmanager configuration</p>
</td>
		</tr>
		<tr>
			<td>alertmanager.configSecret</td>
			<td>string</td>
			<td><pre lang="">
""
</pre>
</td>
			<td><p>if this one defined, it will be used for alertmanager configuration and config parameter will be ignored</p>
</td>
		</tr>
		<tr>
			<td>alertmanager.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>alertmanager.ingress</td>
			<td>object</td>
			<td><pre lang="plaintext">
annotations: {}
enabled: false
extraPaths: []
hosts:
    - alertmanager.domain.com
labels: {}
path: /
pathType: Prefix
tls: []
</pre>
</td>
			<td><p>alertmanager ingress configuration</p>
</td>
		</tr>
		<tr>
			<td>alertmanager.monzoTemplate.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>alertmanager.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
externalURL: ""
image:
    tag: v0.25.0
routePrefix: /
selectAllByDefault: true
</pre>
</td>
			<td><p>full spec for VMAlertmanager CRD. Allowed values described <a href="https://docs.victoriametrics.com/operator/api#vmalertmanagerspec" target="_blank">here</a></p>
</td>
		</tr>
		<tr>
			<td>alertmanager.templateFiles</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>extra alert templates</p>
</td>
		</tr>
		<tr>
			<td>argocdReleaseOverride</td>
			<td>string</td>
			<td><pre lang="">
""
</pre>
</td>
			<td><p>For correct working need set value &lsquo;argocdReleaseOverride=$ARGOCD_APP_NAME&rsquo;</p>
</td>
		</tr>
		<tr>
			<td>coreDns.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>coreDns.service.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>coreDns.service.port</td>
			<td>int</td>
			<td><pre lang="">
9153
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>coreDns.service.selector.k8s-app</td>
			<td>string</td>
			<td><pre lang="">
kube-dns
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>coreDns.service.targetPort</td>
			<td>int</td>
			<td><pre lang="">
9153
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>coreDns.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
endpoints:
    - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
      port: http-metrics
jobLabel: jobLabel
</pre>
</td>
			<td><p><a href="https://docs.victoriametrics.com/operator/api#vmservicescrapespec" target="_blank">Scrape configuration</a> for CoreDNS</p>
</td>
		</tr>
		<tr>
			<td>crds.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultDashboardsEnabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.alerting</td>
			<td>object</td>
			<td><pre lang="plaintext">
spec:
    annotations: {}
    labels: {}
</pre>
</td>
			<td><p>Common properties for VMRules alerts</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.alerting.spec.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>Additional annotations for VMRule alerts</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.alerting.spec.labels</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>Additional labels for VMRule alerts</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>Annotations for default rules</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.group</td>
			<td>object</td>
			<td><pre lang="plaintext">
spec:
    params: {}
</pre>
</td>
			<td><p>Common properties for VMRule groups</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.group.spec.params</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>Optional HTTP URL parameters added to each rule request</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.groups.alertmanager.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.alertmanager.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.etcd.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.etcd.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>Common properties for all rules in a group</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.groups.general.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.general.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sContainerCpuUsageSecondsTotal.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sContainerCpuUsageSecondsTotal.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sContainerMemoryCache.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sContainerMemoryCache.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sContainerMemoryRss.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sContainerMemoryRss.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sContainerMemorySwap.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sContainerMemorySwap.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sContainerMemoryWorkingSetBytes.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sContainerMemoryWorkingSetBytes.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sContainerResource.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sContainerResource.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sPodOwner.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.k8sPodOwner.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeApiserver.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeApiserver.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeApiserverAvailability.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeApiserverAvailability.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeApiserverBurnrate.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeApiserverBurnrate.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeApiserverHistogram.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeApiserverHistogram.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeApiserverSlos.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeApiserverSlos.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubePrometheusGeneral.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubePrometheusGeneral.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubePrometheusNodeRecording.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubePrometheusNodeRecording.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeScheduler.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeScheduler.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeStateMetrics.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubeStateMetrics.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubelet.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubelet.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesApps.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesApps.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesApps.targetNamespace</td>
			<td>string</td>
			<td><pre lang="">
.*
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesResources.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesResources.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesStorage.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesStorage.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesStorage.targetNamespace</td>
			<td>string</td>
			<td><pre lang="">
.*
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesSystem.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesSystem.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesSystemApiserver.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesSystemApiserver.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesSystemControllerManager.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesSystemControllerManager.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesSystemKubelet.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesSystemKubelet.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesSystemScheduler.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.kubernetesSystemScheduler.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.node.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.node.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.nodeNetwork.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.nodeNetwork.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.vmHealth.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.vmHealth.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.vmagent.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.vmagent.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.vmcluster.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.vmcluster.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.vmoperator.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.vmoperator.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.vmsingle.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.groups.vmsingle.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>defaultRules.labels</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>Labels for default rules</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.recording</td>
			<td>object</td>
			<td><pre lang="plaintext">
spec:
    annotations: {}
    labels: {}
</pre>
</td>
			<td><p>Common properties for VMRules recording rules</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.recording.spec.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>Additional annotations for VMRule recording rules</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.recording.spec.labels</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>Additional labels for VMRule recording rules</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.rule</td>
			<td>object</td>
			<td><pre lang="plaintext">
spec:
    annotations: {}
    labels: {}
</pre>
</td>
			<td><p>Common properties for all VMRules</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.rule.spec.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>Additional annotations for all VMRules</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.rule.spec.labels</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>Additional labels for all VMRules</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.rules</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>Per rule properties</p>
</td>
		</tr>
		<tr>
			<td>defaultRules.runbookUrl</td>
			<td>string</td>
			<td><pre lang="">
https://runbooks.prometheus-operator.dev/runbooks
</pre>
</td>
			<td><p>Runbook url prefix for default rules</p>
</td>
		</tr>
		<tr>
			<td>experimentalDashboardsEnabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>externalVM.read.url</td>
			<td>string</td>
			<td><pre lang="">
""
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>externalVM.write.url</td>
			<td>string</td>
			<td><pre lang="">
""
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>extraObjects</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td><p>Add extra objects dynamically to this chart</p>
</td>
		</tr>
		<tr>
			<td>fullnameOverride</td>
			<td>string</td>
			<td><pre lang="">
""
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>global.license.key</td>
			<td>string</td>
			<td><pre lang="">
""
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>global.license.keyRef</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.additionalDataSources</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.dashboardProviders."dashboardproviders.yaml".apiVersion</td>
			<td>int</td>
			<td><pre lang="">
1
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.dashboardProviders."dashboardproviders.yaml".providers[0].disableDeletion</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.dashboardProviders."dashboardproviders.yaml".providers[0].editable</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.dashboardProviders."dashboardproviders.yaml".providers[0].folder</td>
			<td>string</td>
			<td><pre lang="">
""
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.dashboardProviders."dashboardproviders.yaml".providers[0].name</td>
			<td>string</td>
			<td><pre lang="">
default
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.dashboardProviders."dashboardproviders.yaml".providers[0].options.path</td>
			<td>string</td>
			<td><pre lang="">
/var/lib/grafana/dashboards/default
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.dashboardProviders."dashboardproviders.yaml".providers[0].orgId</td>
			<td>int</td>
			<td><pre lang="">
1
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.dashboardProviders."dashboardproviders.yaml".providers[0].type</td>
			<td>string</td>
			<td><pre lang="">
file
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.dashboards.default.nodeexporter.datasource</td>
			<td>string</td>
			<td><pre lang="">
VictoriaMetrics
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.dashboards.default.nodeexporter.gnetId</td>
			<td>int</td>
			<td><pre lang="">
1860
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.dashboards.default.nodeexporter.revision</td>
			<td>int</td>
			<td><pre lang="">
22
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.defaultDashboardsTimezone</td>
			<td>string</td>
			<td><pre lang="">
utc
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.defaultDatasourceType</td>
			<td>string</td>
			<td><pre lang="">
prometheus
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.forceDeployDatasource</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.ingress.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.ingress.enabled</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.ingress.extraPaths</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.ingress.hosts[0]</td>
			<td>string</td>
			<td><pre lang="">
grafana.domain.com
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.ingress.labels</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.ingress.path</td>
			<td>string</td>
			<td><pre lang="">
/
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.ingress.pathType</td>
			<td>string</td>
			<td><pre lang="">
Prefix
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.ingress.tls</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.provisionDefaultDatasource</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.sidecar.dashboards.additionalDashboardAnnotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.sidecar.dashboards.additionalDashboardLabels</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.sidecar.dashboards.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.sidecar.dashboards.multicluster</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.sidecar.datasources.createVMReplicasDatasources</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.sidecar.datasources.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.sidecar.datasources.initDatasources</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.sidecar.datasources.jsonData</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.vmServiceScrape.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafana.vmServiceScrape.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p><a href="https://docs.victoriametrics.com/operator/api#vmservicescrapespec" target="_blank">Scrape configuration</a> for Grafana</p>
</td>
		</tr>
		<tr>
			<td>grafanaOperatorDashboardsFormat.allowCrossNamespaceImport</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafanaOperatorDashboardsFormat.enabled</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>grafanaOperatorDashboardsFormat.instanceSelector.matchLabels.dashboards</td>
			<td>string</td>
			<td><pre lang="">
grafana
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kube-state-metrics.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kube-state-metrics.vmServiceScrape</td>
			<td>object</td>
			<td><pre lang="plaintext">
spec: {}
</pre>
</td>
			<td><p><a href="https://docs.victoriametrics.com/operator/api#vmservicescrapespec" target="_blank">Scrape configuration</a> for Kube State Metrics</p>
</td>
		</tr>
		<tr>
			<td>kubeApiServer</td>
			<td>object</td>
			<td><pre lang="plaintext">
enabled: true
spec:
    endpoints:
        - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
          port: https
          scheme: https
          tlsConfig:
            caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            serverName: kubernetes
    jobLabel: component
    namespaceSelector:
        matchNames:
            - default
    selector:
        matchLabels:
            component: apiserver
            provider: kubernetes
</pre>
</td>
			<td><p>Component scraping the kube api server</p>
</td>
		</tr>
		<tr>
			<td>kubeApiServer.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
endpoints:
    - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
      port: https
      scheme: https
      tlsConfig:
        caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        serverName: kubernetes
jobLabel: component
namespaceSelector:
    matchNames:
        - default
selector:
    matchLabels:
        component: apiserver
        provider: kubernetes
</pre>
</td>
			<td><p><a href="https://docs.victoriametrics.com/operator/api#vmservicescrapespec" target="_blank">Scrape configuration</a> for Kube API Server</p>
</td>
		</tr>
		<tr>
			<td>kubeControllerManager</td>
			<td>object</td>
			<td><pre lang="plaintext">
enabled: true
endpoints: []
service:
    enabled: true
    port: 10257
    selector:
        component: kube-controller-manager
    targetPort: 10257
spec:
    endpoints:
        - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
          port: http-metrics
          scheme: https
          tlsConfig:
            caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            serverName: kubernetes
    jobLabel: jobLabel
</pre>
</td>
			<td><p>Component scraping the kube controller manager</p>
</td>
		</tr>
		<tr>
			<td>kubeControllerManager.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
endpoints:
    - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
      port: http-metrics
      scheme: https
      tlsConfig:
        caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        serverName: kubernetes
jobLabel: jobLabel
</pre>
</td>
			<td><p><a href="https://docs.victoriametrics.com/operator/api#vmservicescrapespec" target="_blank">Scrape configuration</a> for Kube Controller Manager</p>
</td>
		</tr>
		<tr>
			<td>kubeDns.enabled</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeDns.service.dnsmasq.port</td>
			<td>int</td>
			<td><pre lang="">
10054
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeDns.service.dnsmasq.targetPort</td>
			<td>int</td>
			<td><pre lang="">
10054
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeDns.service.enabled</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeDns.service.selector.k8s-app</td>
			<td>string</td>
			<td><pre lang="">
kube-dns
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeDns.service.skydns.port</td>
			<td>int</td>
			<td><pre lang="">
10055
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeDns.service.skydns.targetPort</td>
			<td>int</td>
			<td><pre lang="">
10055
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeDns.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
endpoints:
    - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
      port: http-metrics-dnsmasq
    - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
      port: http-metrics-skydns
</pre>
</td>
			<td><p><a href="https://docs.victoriametrics.com/operator/api#vmservicescrapespec" target="_blank">Scrape configuration</a> for KubeDNS</p>
</td>
		</tr>
		<tr>
			<td>kubeEtcd.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeEtcd.endpoints</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeEtcd.service.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeEtcd.service.port</td>
			<td>int</td>
			<td><pre lang="">
2379
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeEtcd.service.selector.component</td>
			<td>string</td>
			<td><pre lang="">
etcd
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeEtcd.service.targetPort</td>
			<td>int</td>
			<td><pre lang="">
2379
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeEtcd.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
endpoints:
    - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
      port: http-metrics
      scheme: https
      tlsConfig:
        caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
jobLabel: jobLabel
</pre>
</td>
			<td><p><a href="https://docs.victoriametrics.com/operator/api#vmservicescrapespec" target="_blank">Scrape configuration</a> for ETCD</p>
</td>
		</tr>
		<tr>
			<td>kubeProxy.enabled</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeProxy.endpoints</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeProxy.service.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeProxy.service.port</td>
			<td>int</td>
			<td><pre lang="">
10249
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeProxy.service.selector.k8s-app</td>
			<td>string</td>
			<td><pre lang="">
kube-proxy
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeProxy.service.targetPort</td>
			<td>int</td>
			<td><pre lang="">
10249
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeProxy.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
endpoints:
    - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
      port: http-metrics
      scheme: https
      tlsConfig:
        caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
jobLabel: jobLabel
</pre>
</td>
			<td><p><a href="https://docs.victoriametrics.com/operator/api#vmservicescrapespec" target="_blank">Scrape configuration</a> for Kube Proxy</p>
</td>
		</tr>
		<tr>
			<td>kubeScheduler.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeScheduler.endpoints</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeScheduler.service.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeScheduler.service.port</td>
			<td>int</td>
			<td><pre lang="">
10259
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeScheduler.service.selector.component</td>
			<td>string</td>
			<td><pre lang="">
kube-scheduler
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeScheduler.service.targetPort</td>
			<td>int</td>
			<td><pre lang="">
10259
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubeScheduler.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
endpoints:
    - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
      port: http-metrics
      scheme: https
      tlsConfig:
        caFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
jobLabel: jobLabel
</pre>
</td>
			<td><p><a href="https://docs.victoriametrics.com/operator/api#vmservicescrapespec" target="_blank">Scrape configuration</a> for Kube Scheduler</p>
</td>
		</tr>
		<tr>
			<td>kubelet.cadvisor</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td><p>Enable scraping /metrics/cadvisor from kubelet&rsquo;s service</p>
</td>
		</tr>
		<tr>
			<td>kubelet.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.probes</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td><p>Enable scraping /metrics/probes from kubelet&rsquo;s service</p>
</td>
		</tr>
		<tr>
			<td>kubelet.spec.bearerTokenFile</td>
			<td>string</td>
			<td><pre lang="">
/var/run/secrets/kubernetes.io/serviceaccount/token
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.honorLabels</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.honorTimestamps</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.interval</td>
			<td>string</td>
			<td><pre lang="">
30s
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.metricRelabelConfigs[0].action</td>
			<td>string</td>
			<td><pre lang="">
labeldrop
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.metricRelabelConfigs[0].regex</td>
			<td>string</td>
			<td><pre lang="">
(uid)
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.metricRelabelConfigs[1].action</td>
			<td>string</td>
			<td><pre lang="">
labeldrop
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.metricRelabelConfigs[1].regex</td>
			<td>string</td>
			<td><pre lang="">
(id|name)
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.metricRelabelConfigs[2].action</td>
			<td>string</td>
			<td><pre lang="">
drop
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.metricRelabelConfigs[2].regex</td>
			<td>string</td>
			<td><pre lang="">
(rest_client_request_duration_seconds_bucket|rest_client_request_duration_seconds_sum|rest_client_request_duration_seconds_count)
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.metricRelabelConfigs[2].source_labels[0]</td>
			<td>string</td>
			<td><pre lang="">
__name__
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.relabelConfigs[0].action</td>
			<td>string</td>
			<td><pre lang="">
labelmap
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.relabelConfigs[0].regex</td>
			<td>string</td>
			<td><pre lang="">
__meta_kubernetes_node_label_(.+)
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.relabelConfigs[1].sourceLabels[0]</td>
			<td>string</td>
			<td><pre lang="">
__metrics_path__
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.relabelConfigs[1].targetLabel</td>
			<td>string</td>
			<td><pre lang="">
metrics_path
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.relabelConfigs[2].replacement</td>
			<td>string</td>
			<td><pre lang="">
kubelet
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.relabelConfigs[2].targetLabel</td>
			<td>string</td>
			<td><pre lang="">
job
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.scheme</td>
			<td>string</td>
			<td><pre lang="">
https
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.scrapeTimeout</td>
			<td>string</td>
			<td><pre lang="">
5s
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.tlsConfig.caFile</td>
			<td>string</td>
			<td><pre lang="">
/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>kubelet.spec.tlsConfig.insecureSkipVerify</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>nameOverride</td>
			<td>string</td>
			<td><pre lang="">
""
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>prometheus-node-exporter.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>prometheus-node-exporter.extraArgs[0]</td>
			<td>string</td>
			<td><pre lang="">
--collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/.+)($|/)
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>prometheus-node-exporter.extraArgs[1]</td>
			<td>string</td>
			<td><pre lang="">
--collector.filesystem.ignored-fs-types=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>prometheus-node-exporter.podLabels.jobLabel</td>
			<td>string</td>
			<td><pre lang="">
node-exporter
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>prometheus-node-exporter.vmServiceScrape.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>prometheus-node-exporter.vmServiceScrape.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
endpoints:
    - metricRelabelConfigs:
        - action: drop
          regex: /var/lib/kubelet/pods.+
          source_labels:
            - mountpoint
      port: metrics
jobLabel: jobLabel
</pre>
</td>
			<td><p><a href="https://docs.victoriametrics.com/operator/api#vmservicescrapespec" target="_blank">Scrape configuration</a> for Node Exporter</p>
</td>
		</tr>
		<tr>
			<td>prometheus-operator-crds.enabled</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>serviceAccount.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>Annotations to add to the service account</p>
</td>
		</tr>
		<tr>
			<td>serviceAccount.create</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td><p>Specifies whether a service account should be created</p>
</td>
		</tr>
		<tr>
			<td>serviceAccount.name</td>
			<td>string</td>
			<td><pre lang="">
""
</pre>
</td>
			<td><p>If not set and create is true, a name is generated using the fullname template</p>
</td>
		</tr>
		<tr>
			<td>tenant</td>
			<td>string</td>
			<td><pre lang="">
"0"
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>victoria-metrics-operator</td>
			<td>object</td>
			<td><pre lang="plaintext">
cleanupCRD: true
cleanupImage:
    pullPolicy: IfNotPresent
    repository: bitnami/kubectl
    tag: ""
createCRD: false
enabled: true
operator:
    disable_prometheus_converter: false
</pre>
</td>
			<td><p>also checkout here possible ENV variables to configure operator behaviour <a href="https://docs.victoriametrics.com/operator/vars" target="_blank">https://docs.victoriametrics.com/operator/vars</a></p>
</td>
		</tr>
		<tr>
			<td>victoria-metrics-operator.cleanupCRD</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td><p>Tells helm to clean up vm cr resources when uninstalling</p>
</td>
		</tr>
		<tr>
			<td>victoria-metrics-operator.cleanupImage.repository</td>
			<td>string</td>
			<td><pre lang="">
bitnami/kubectl
</pre>
</td>
			<td><p>cleanup image repository</p>
</td>
		</tr>
		<tr>
			<td>victoria-metrics-operator.cleanupImage.tag</td>
			<td>string</td>
			<td><pre lang="">
""
</pre>
</td>
			<td><p>use image tag that matches k8s API version by default</p>
</td>
		</tr>
		<tr>
			<td>victoria-metrics-operator.operator.disable_prometheus_converter</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td><p>By default, operator converts prometheus-operator objects.</p>
</td>
		</tr>
		<tr>
			<td>vmagent.additionalRemoteWrites</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td><p>remoteWrite configuration of VMAgent, allowed parameters defined in a <a href="https://docs.victoriametrics.com/operator/api#vmagentremotewritespec" target="_blank">spec</a></p>
</td>
		</tr>
		<tr>
			<td>vmagent.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmagent.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmagent.ingress</td>
			<td>object</td>
			<td><pre lang="plaintext">
annotations: {}
enabled: false
extraPaths: []
hosts:
    - vmagent.domain.com
labels: {}
path: /
pathType: Prefix
tls: []
</pre>
</td>
			<td><p>vmagent ingress configuration</p>
</td>
		</tr>
		<tr>
			<td>vmagent.ingress.extraPaths</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td><p>Extra paths to prepend to every host configuration. This is useful when working with annotation based services.</p>
</td>
		</tr>
		<tr>
			<td>vmagent.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
externalLabels: {}
extraArgs:
    promscrape.dropOriginalLabels: "true"
    promscrape.streamParse: "true"
image:
    tag: v1.102.1
scrapeInterval: 20s
selectAllByDefault: true
</pre>
</td>
			<td><p>full spec for VMAgent CRD. Allowed values described <a href="https://docs.victoriametrics.com/operator/api#vmagentspec" target="_blank">here</a></p>
</td>
		</tr>
		<tr>
			<td>vmalert.additionalNotifierConfigs</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmalert.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmalert.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmalert.ingress</td>
			<td>object</td>
			<td><pre lang="plaintext">
annotations: {}
enabled: false
extraPaths: []
hosts:
    - vmalert.domain.com
labels: {}
path: /
pathType: Prefix
tls: []
</pre>
</td>
			<td><p>vmalert ingress config</p>
</td>
		</tr>
		<tr>
			<td>vmalert.remoteWriteVMAgent</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmalert.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
evaluationInterval: 15s
externalLabels: {}
image:
    tag: v1.102.1
selectAllByDefault: true
</pre>
</td>
			<td><p>full spec for VMAlert CRD. Allowed values described <a href="https://docs.victoriametrics.com/operator/api#vmalertspec" target="_blank">here</a></p>
</td>
		</tr>
		<tr>
			<td>vmalert.templateFiles</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td><p>extra vmalert annotation templates</p>
</td>
		</tr>
		<tr>
			<td>vmcluster.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.enabled</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.insert.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.insert.enabled</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.insert.extraPaths</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.insert.hosts[0]</td>
			<td>string</td>
			<td><pre lang="">
vminsert.domain.com
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.insert.labels</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.insert.path</td>
			<td>string</td>
			<td><pre lang="">
/
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.insert.pathType</td>
			<td>string</td>
			<td><pre lang="">
Prefix
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.insert.tls</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.select.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.select.enabled</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.select.extraPaths</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.select.hosts[0]</td>
			<td>string</td>
			<td><pre lang="">
vmselect.domain.com
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.select.labels</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.select.path</td>
			<td>string</td>
			<td><pre lang="">
/
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.select.pathType</td>
			<td>string</td>
			<td><pre lang="">
Prefix
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.select.tls</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.storage.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.storage.enabled</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.storage.extraPaths</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.storage.hosts[0]</td>
			<td>string</td>
			<td><pre lang="">
vmstorage.domain.com
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.storage.labels</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.storage.path</td>
			<td>string</td>
			<td><pre lang="">
/
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.storage.pathType</td>
			<td>string</td>
			<td><pre lang="">
Prefix
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.ingress.storage.tls</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmcluster.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
replicationFactor: 2
retentionPeriod: "1"
vminsert:
    extraArgs: {}
    image:
        tag: v1.102.1-cluster
    replicaCount: 2
    resources: {}
vmselect:
    cacheMountPath: /select-cache
    extraArgs: {}
    image:
        tag: v1.102.1-cluster
    replicaCount: 2
    resources: {}
    storage:
        volumeClaimTemplate:
            spec:
                resources:
                    requests:
                        storage: 2Gi
vmstorage:
    image:
        tag: v1.102.1-cluster
    replicaCount: 2
    resources: {}
    storage:
        volumeClaimTemplate:
            spec:
                resources:
                    requests:
                        storage: 10Gi
    storageDataPath: /vm-data
</pre>
</td>
			<td><p>full spec for VMCluster CRD. Allowed values described <a href="https://docs.victoriametrics.com/operator/api#vmclusterspec" target="_blank">here</a></p>
</td>
		</tr>
		<tr>
			<td>vmcluster.spec.retentionPeriod</td>
			<td>string</td>
			<td><pre lang="">
"1"
</pre>
</td>
			<td><p>Data retention period. Possible units character: h(ours), d(ays), w(eeks), y(ears), if no unit character specified - month. The minimum retention period is 24h. See these <a href="https://docs.victoriametrics.com/single-server-victoriametrics/#retention" target="_blank">docs</a></p>
</td>
		</tr>
		<tr>
			<td>vmsingle.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmsingle.enabled</td>
			<td>bool</td>
			<td><pre lang="">
true
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmsingle.ingress.annotations</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmsingle.ingress.enabled</td>
			<td>bool</td>
			<td><pre lang="">
false
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmsingle.ingress.extraPaths</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmsingle.ingress.hosts[0]</td>
			<td>string</td>
			<td><pre lang="">
vmsingle.domain.com
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmsingle.ingress.labels</td>
			<td>object</td>
			<td><pre lang="plaintext">
{}
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmsingle.ingress.path</td>
			<td>string</td>
			<td><pre lang="">
/
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmsingle.ingress.pathType</td>
			<td>string</td>
			<td><pre lang="">
Prefix
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmsingle.ingress.tls</td>
			<td>list</td>
			<td><pre lang="plaintext">
[]
</pre>
</td>
			<td></td>
		</tr>
		<tr>
			<td>vmsingle.spec</td>
			<td>object</td>
			<td><pre lang="plaintext">
extraArgs: {}
image:
    tag: v1.102.1
replicaCount: 1
retentionPeriod: "1"
storage:
    accessModes:
        - ReadWriteOnce
    resources:
        requests:
            storage: 20Gi
</pre>
</td>
			<td><p>full spec for VMSingle CRD. Allowed values describe <a href="https://docs.victoriametrics.com/operator/api#vmsinglespec" target="_blank">here</a></p>
</td>
		</tr>
		<tr>
			<td>vmsingle.spec.retentionPeriod</td>
			<td>string</td>
			<td><pre lang="">
"1"
</pre>
</td>
			<td><p>Data retention period. Possible units character: h(ours), d(ays), w(eeks), y(ears), if no unit character specified - month. The minimum retention period is 24h. See these <a href="https://docs.victoriametrics.com/single-server-victoriametrics/#retention" target="_blank">docs</a></p>
</td>
		</tr>
	</tbody>
</table>

