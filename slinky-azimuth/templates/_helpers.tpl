{{/*
Expand the name of the chart.
*/}}
{{- define "slinky-azimuth.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "slinky-azimuth.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "slinky-azimuth.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels for a chart-level resource.
*/}}
{{- define "slinky-azimuth.selectorLabels" -}}
app.kubernetes.io/name: {{ include "slinky-azimuth.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Labels for a chart-level resource.
*/}}
{{- define "slinky-azimuth.labels" -}}
helm.sh/chart: {{ include "slinky-azimuth.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{ include "slinky-azimuth.selectorLabels" . }}
{{- end }}
