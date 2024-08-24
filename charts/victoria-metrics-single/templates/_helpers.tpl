{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "victoria-metrics.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "victoria-metrics.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "victoria-metrics.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account
*/}}
{{- define "victoria-metrics.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "victoria-metrics.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Create unified labels for victoria-metrics components
*/}}
{{- define "victoria-metrics.common.matchLabels" -}}
app.kubernetes.io/name: {{ include "victoria-metrics.name" . }}
app.kubernetes.io/instance: {{ .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "victoria-metrics.common.metaLabels" -}}
helm.sh/chart: {{ include "victoria-metrics.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service | trunc 63 | trimSuffix "-" }}
{{- with .extraLabels }}
{{ toYaml .}}
{{- end }}
{{- end -}}

{{- define "victoria-metrics.server.labels" -}}
{{ include "victoria-metrics.server.matchLabels" . }}
{{ include "victoria-metrics.common.metaLabels" . }}
{{- end -}}

{{- define "victoria-metrics.server.matchLabels" -}}
app: {{ .Values.server.name }}
{{ include "victoria-metrics.common.matchLabels" . }}
{{- end -}}

{{/*
Create a fully qualified server name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "victoria-metrics.server.fullname" -}}
{{- if .Values.server.fullnameOverride -}}
{{- .Values.server.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf "%s-%s" .Release.Name .Values.server.name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name $name .Values.server.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Defines the name of scrape configuration map
*/}}
{{- define "victoria-metrics.server.scrape.configname" -}}
{{- if .Values.server.scrape.configMap -}}
{{- .Values.server.scrape.configMap -}}
{{- else -}}
{{- include "victoria-metrics.server.fullname" . -}}-scrapeconfig
{{- end -}}
{{- end -}}

{{/*
Defines the name of relabel configuration map
*/}}
{{- define "victoria-metrics.server.relabel.configname" -}}
{{- if .Values.server.relabel.configMap -}}
{{- .Values.server.relabel.configMap -}}
{{- else -}}
{{- include "victoria-metrics.server.fullname" . -}}-relabelconfig
{{- end -}}
{{- end -}}

{{/*
Enforce license for vmbackupmanager
*/}}
{{- define "victoria-metrics.vmbackupmanager.enforce_license" -}}
{{ if and .Values.server.vmbackupmanager.enable (not (or .Values.server.vmbackupmanager.eula .Values.license.key .Values.license.secret.name)) }}
{{ fail `Pass -eula command-line flag or valid license at .Values.license if you have an enterprise license for running this software.
  See https://victoriametrics.com/legal/esa/ for details.
  Documentation - https://docs.victoriametrics.com/enterprise.html
  for more information, visit https://victoriametrics.com/products/enterprise/
  To request a trial license, go to https://victoriametrics.com/products/enterprise/trial/`}}
{{- end -}}
{{- end -}}
