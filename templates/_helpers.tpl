{{/*
Expand the name of the chart.
*/}}
{{- define "k8s-service-template.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "k8s-service-template.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "k8s-service-template.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "k8s-service-template.labels" -}}
helm.sh/chart: {{ include "k8s-service-template.chart" . }}
{{ include "k8s-service-template.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ include "k8s-service-template.name" . }}
environment: {{ .Values.global.environment }}
project: {{ .Values.global.project }}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "k8s-service-template.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8s-service-template.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "k8s-service-template.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "k8s-service-template.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database selector labels
*/}}
{{- define "k8s-service-template.database.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8s-service-template.name" . }}-db
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: database
{{- end }}

{{/*
Database labels
*/}}
{{- define "k8s-service-template.database.labels" -}}
helm.sh/chart: {{ include "k8s-service-template.chart" . }}
{{ include "k8s-service-template.database.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ include "k8s-service-template.name" . }}
environment: {{ .Values.global.environment }}
project: {{ .Values.global.project }}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
{{- end }}

{{/*
TargetGroupBinding selector labels
*/}}
{{- define "k8s-service-template.targetGroupBinding.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8s-service-template.name" . }}-tgb
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: target-group-binding
{{- end }}

{{/*
TargetGroupBinding labels
*/}}
{{- define "k8s-service-template.targetGroupBinding.labels" -}}
helm.sh/chart: {{ include "k8s-service-template.chart" . }}
{{ include "k8s-service-template.targetGroupBinding.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ include "k8s-service-template.name" . }}
environment: {{ .Values.global.environment }}
project: {{ .Values.global.project }}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "k8s-service-template.annotations" -}}
{{- if .Values.commonAnnotations }}
{{ toYaml .Values.commonAnnotations }}
{{- end }}
{{- end }}

{{/*
Generate container environment variables
*/}}
{{- define "k8s-service-template.env" -}}
{{- range $key, $value := .Values.env.variables }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- if .Values.env.configMapRef }}
- name: CONFIG_MAP_REF
  valueFrom:
    configMapKeyRef:
      name: {{ .Values.env.configMapRef }}
      key: data
{{- end }}
{{- if .Values.env.secretRef }}
- name: SECRET_REF
  valueFrom:
    secretKeyRef:
      name: {{ .Values.env.secretRef }}
      key: data
{{- end }}
{{- end }}

{{/*
Generate security context
*/}}
{{- define "k8s-service-template.securityContext" -}}
{{- if .Values.securityContext.enabled }}
securityContext:
  runAsNonRoot: {{ .Values.securityContext.runAsNonRoot }}
  runAsUser: {{ .Values.securityContext.runAsUser }}
  runAsGroup: {{ .Values.securityContext.runAsGroup }}
  fsGroup: {{ .Values.securityContext.fsGroup }}
{{- end }}
{{- end }}

{{/*
Generate image pull secrets
*/}}
{{- define "k8s-service-template.imagePullSecrets" -}}
{{- if .Values.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate persistent volume claims for app
*/}}
{{- define "k8s-service-template.volumeClaims" -}}
{{- if .Values.persistence.enabled }}
{{- range .Values.persistence.volumes }}
- name: {{ .name }}
  persistentVolumeClaim:
    claimName: {{ include "k8s-service-template.fullname" $ }}-{{ .name }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate volume mounts for app
*/}}
{{- define "k8s-service-template.volumeMounts" -}}
{{- if .Values.persistence.enabled }}
{{- range .Values.persistence.volumes }}
- name: {{ .name }}
  mountPath: {{ .mountPath }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate config file volumes
*/}}
{{- define "k8s-service-template.configFileVolumes" -}}
{{- if .Values.configFiles.enabled }}
{{- if .Values.configFiles.pvc.enabled }}
{{- range .Values.configFiles.pvc.volumes }}
- name: {{ .name }}
  persistentVolumeClaim:
    claimName: {{ .claimName }}
{{- end }}
{{- end }}
{{- if .Values.configFiles.hostPath.enabled }}
{{- range .Values.configFiles.hostPath.volumes }}
- name: {{ .name }}
  hostPath:
    path: {{ .path }}
    type: {{ .type | default "File" }}
{{- end }}
{{- end }}
{{- if .Values.configFiles.initContainer.enabled }}
- name: config-temp
  emptyDir: {}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate config file volume mounts
*/}}
{{- define "k8s-service-template.configFileMounts" -}}
{{- if .Values.configFiles.enabled }}
{{- if .Values.configFiles.pvc.enabled }}
{{- range .Values.configFiles.pvc.volumes }}
- name: {{ .name }}
  mountPath: {{ .mountPath }}
  {{- if .subPath }}
  subPath: {{ .subPath }}
  {{- end }}
  {{- if .readOnly }}
  readOnly: {{ .readOnly }}
  {{- end }}
{{- end }}
{{- end }}
{{- if .Values.configFiles.hostPath.enabled }}
{{- range .Values.configFiles.hostPath.volumes }}
- name: {{ .name }}
  mountPath: {{ .mountPath }}
  {{- if .readOnly }}
  readOnly: {{ .readOnly }}
  {{- end }}
{{- end }}
{{- end }}
{{- if .Values.configFiles.initContainer.enabled }}
{{- range .Values.configFiles.initContainer.sources }}
- name: config-temp
  mountPath: {{ .mountPath }}
  {{- if .subPath }}
  subPath: {{ .subPath }}
  {{- end }}
  readOnly: true
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate init container for config fetching
*/}}
{{- define "k8s-service-template.configInitContainer" -}}
{{- if and .Values.configFiles.enabled .Values.configFiles.initContainer.enabled }}
- name: config-fetcher
  image: {{ .Values.configFiles.initContainer.image }}
  command:
    - /bin/sh
    - -c
    - |
      {{- range .Values.configFiles.initContainer.sources }}
      {{- if eq .method "s3" }}
      # Download from S3 (requires aws cli in image)
      aws s3 cp {{ .url | quote }} /tmp/config/{{ .subPath | default "config.yaml" }}
      {{- else if eq .method "http" }}
      # Download via HTTP
      wget -O /tmp/config/{{ .subPath | default "config.yaml" }} {{ .url | quote }}
      {{- else if eq .method "git" }}
      # Clone from git (requires git in image)
      git clone {{ .url | quote }} /tmp/git-repo
      cp /tmp/git-repo/{{ .path | default "config.yaml" }} /tmp/config/{{ .subPath | default "config.yaml" }}
      {{- else }}
      # Default: assume HTTP
      wget -O /tmp/config/{{ .subPath | default "config.yaml" }} {{ .url | quote }}
      {{- end }}
      {{- end }}
  volumeMounts:
    - name: config-temp
      mountPath: /tmp/config
  {{- if .Values.configFiles.initContainer.resources }}
  resources:
    {{- toYaml .Values.configFiles.initContainer.resources | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Multi-deployment selector labels
*/}}
{{- define "k8s-service-template.deployment.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8s-service-template.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end }}

{{/*
Multi-deployment labels
*/}}
{{- define "k8s-service-template.deployment.labels" -}}
helm.sh/chart: {{ include "k8s-service-template.chart" . }}
{{ include "k8s-service-template.deployment.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ include "k8s-service-template.name" . }}
environment: {{ .Values.global.environment }}
project: {{ .Values.global.project }}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
{{- end }}

{{/*
HPA behavior defaults
*/}}
{{- define "k8s-service-template.hpa.behavior" -}}
scaleDown:
  stabilizationWindowSeconds: {{ .stabilizationWindowSeconds | default 300 }}
  policies:
  - type: Percent
    value: {{ .percent | default 10 }}
    periodSeconds: {{ .periodSeconds | default 60 }}
scaleUp:
  stabilizationWindowSeconds: {{ .stabilizationWindowSeconds | default 60 }}
  policies:
  - type: Percent
    value: {{ .percent | default 100 }}
    periodSeconds: {{ .periodSeconds | default 15 }}
  - type: Pods
    value: {{ .pods | default 2 }}
    periodSeconds: {{ .periodSeconds | default 60 }}
  selectPolicy: Max
{{- end }}

{{/*
Multi-database selector labels
*/}}
{{- define "k8s-service-template.databases.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8s-service-template.name" .root }}-db
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: database-{{ .name }}
app.kubernetes.io/database-type: {{ .type }}
{{- end }}

{{/*
Multi-database labels
*/}}
{{- define "k8s-service-template.databases.labels" -}}
helm.sh/chart: {{ include "k8s-service-template.chart" .root }}
{{ include "k8s-service-template.databases.selectorLabels" . }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
app.kubernetes.io/part-of: {{ include "k8s-service-template.name" .root }}
environment: {{ .root.Values.global.environment }}
project: {{ .root.Values.global.project }}
{{- if .root.Values.commonLabels }}
{{ toYaml .root.Values.commonLabels }}
{{- end }}
{{- end }}