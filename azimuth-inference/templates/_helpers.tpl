{{- define "azimuth-inference.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "azimuth-inference.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := include "azimuth-inference.name" . }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "azimuth-inference.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "azimuth-inference.componentSelectorLabels" -}}
app.kubernetes.io/name: {{ include "azimuth-inference.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{- define "azimuth-inference.componentLabels" -}}
helm.sh/chart: {{ include "azimuth-inference.chart" .root }}
{{ include "azimuth-inference.componentSelectorLabels" . }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end }}

{{- define "azimuth-inference.selectorLabels" -}}
{{ include "azimuth-inference.componentSelectorLabels" (dict "root" . "component" "inference-api") }}
{{- end }}

{{- define "azimuth-inference.labels" -}}
{{ include "azimuth-inference.componentLabels" (dict "root" . "component" "inference-api") }}
{{- end }}

{{- define "azimuth-inference.image" -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- end }}

{{- define "azimuth-inference.gatewayFullname" -}}
{{- printf "%s-litellm" .Release.Name -}}
{{- end }}

{{- define "azimuth-inference.idempotentSecret" -}}
{{- $existing := index (.existing | default dict) .key | default "" -}}
{{- if .explicit -}}
{{- .explicit | b64enc -}}
{{- else if $existing -}}
{{- $existing -}}
{{- else -}}
{{- .generated | b64enc -}}
{{- end -}}
{{- end }}

{{- define "azimuth-inference.gatewayConfig" -}}
{{- $root := . -}}
{{- $g := $root.Values.litellmConfig -}}
model_list:
{{- range $model := (include "azimuth-inference.models" $root | fromYaml).models }}
{{- $ctx := dict "root" $root "model" $model }}
{{- $profile := include "azimuth-inference.modelProfile" $ctx | fromYaml }}
{{- $alias := include "azimuth-inference.modelAlias" $ctx }}
{{- $sts := include "azimuth-inference.modelFullname" $ctx }}
{{- range $i := until (int $model.replicas) }}
  - model_name: {{ $alias | quote }}
    litellm_params:
      model: {{ printf "openai/%s" $alias | quote }}
      api_base: {{ printf "http://%s-%d.%s.svc.cluster.local/v1" $sts $i $root.Release.Namespace | quote }}
      api_key: os.environ/BACKEND_API_KEY
      timeout: {{ $g.timeouts.request }}
      stream_timeout: {{ $g.timeouts.stream }}
    model_info:
      id: {{ printf "%s-%d" $sts $i | quote }}
      max_input_tokens: {{ div (int $profile.contextSize) (int $profile.parallel) }}
{{- end }}
{{- end }}

router_settings:
  routing_strategy: {{ $g.router.routingStrategy }}
  num_retries: {{ $g.router.numRetries }}
  allowed_fails: {{ $g.router.allowedFails }}
  cooldown_time: {{ $g.router.cooldownTime }}
  enable_pre_call_checks: {{ $g.router.enablePreCallChecks }}
{{- $checks := list -}}
{{- if $g.router.apiKeyAffinity }}{{ $checks = append $checks "deployment_affinity" }}{{ end -}}
{{- if $g.router.sessionAffinity }}{{ $checks = append $checks "session_affinity" }}{{ end -}}
{{- if $checks }}
  optional_pre_call_checks: {{ $checks | toJson }}
  deployment_affinity_ttl_seconds: {{ $g.router.affinityTtlSeconds }}
{{- end }}

litellm_settings:
  drop_params: true
  request_timeout: {{ $g.timeouts.request }}
{{- if $root.Values.monitoring.enabled }}
  callbacks: ["prometheus"]
{{- end }}
{{- if $g.healthCheck.background }}
  background_health_checks: true
  health_check_interval: {{ $g.healthCheck.interval }}
{{- end }}

general_settings:
  master_key: os.environ/PROXY_MASTER_KEY
{{- end }}

{{- define "azimuth-inference.gatewayDbFullname" -}}
{{- $name := printf "%s-gateway-db" (include "azimuth-inference.fullname" .) -}}
{{- if gt (len $name) 52 -}}
{{- fail (printf "%q is %d characters and names a StatefulSet, whose controller appends an 11-character revision hash to it to label every pod, and a label is limited to 63 characters, so this must be 52 or fewer. Shorten the release name" $name (len $name)) -}}
{{- end -}}
{{- $name -}}
{{- end }}

{{- define "azimuth-inference.openWebUIFullname" -}}
{{- $name := printf "%s-webui" (include "azimuth-inference.fullname" .) -}}
{{- if gt (len $name) 46 -}}
{{- fail (printf "%q is %d characters and names a Deployment, whose pods are named \"<this>-<10 hex digits>-<5 characters>\" and are limited to 63 characters in total, so this must be 46 or fewer. Shorten the release name" $name (len $name)) -}}
{{- end -}}
{{- $name -}}
{{- end }}

{{- define "azimuth-inference.modelConfig" -}}
{{- $root := .root -}}
{{- $entry := .entry -}}
{{- $name := required "every models[] entry must set name" $entry.name -}}
{{- $base := dict
      "replicas" 1
      "modelStorage" (deepCopy $root.Values.modelStorage)
      "scheduling" (deepCopy $root.Values.scheduling)
      "service" (deepCopy $root.Values.service)
-}}
{{- $model := mergeOverwrite $base (omit (deepCopy $entry) "name") -}}
{{- $_ := set $model "name" $name -}}
{{- $_ := set $model "profile" (default $name $model.profile) -}}
{{- toYaml $model -}}
{{- end }}

{{- define "azimuth-inference.models" -}}
{{- $root := . -}}
{{- if not $root.Values.models -}}
{{- fail "models must contain at least one entry" -}}
{{- end -}}
{{- $seenNames := dict -}}
{{- $seenAliases := dict -}}
{{- $resolved := list -}}
{{- range $entry := $root.Values.models -}}
{{- $model := include "azimuth-inference.modelConfig" (dict "root" $root "entry" $entry) | fromYaml -}}
{{- $name := $model.name -}}
{{- if not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $name) -}}
{{- fail (printf "models[].name %q must be a lowercase DNS-1123 label, because it becomes part of a Service and StatefulSet name" $name) -}}
{{- end -}}
{{- if hasKey $seenNames $name -}}
{{- fail (printf "duplicate models[].name %q" $name) -}}
{{- end -}}
{{- $_ := set $seenNames $name true -}}
{{- if not (hasKey $root.Values.profiles $model.profile) -}}
{{- fail (printf "model %q references unknown profile %q" $name $model.profile) -}}
{{- end -}}
{{- $_ := include "azimuth-inference.modelArtifacts" (dict "root" $root "model" $model) -}}
{{- $alias := include "azimuth-inference.modelAlias" (dict "root" $root "model" $model) -}}
{{- if hasKey $seenAliases $alias -}}
{{- fail (printf "models[] entries %q and %q both serve alias %q, which is the OpenAI model name a gateway routes on; set modelAlias on one of them" (index $seenAliases $alias) $name $alias) -}}
{{- end -}}
{{- $_ := set $seenAliases $alias $name -}}
{{- $fullname := printf "%s-%s" (include "azimuth-inference.fullname" $root) $name -}}
{{- if gt (len $fullname) 52 -}}
{{- fail (printf "%q is %d characters; the StatefulSet controller appends an 11-character revision hash to it to label every pod, and a label is limited to 63 characters, so this must be 52 or fewer. Shorten the release name or the model name" $fullname (len $fullname)) -}}
{{- end -}}
{{- if and $model.modelStorage.existingClaim (gt (int $model.replicas) 1) -}}
{{- fail (printf "model %q sets modelStorage.existingClaim with replicas %d: a Cinder volume is ReadWriteOnce and supports exactly one pod" $name (int $model.replicas)) -}}
{{- end -}}
{{- $resolved = append $resolved $model -}}
{{- end -}}
{{- toYaml (dict "models" $resolved) -}}
{{- end }}

{{- define "azimuth-inference.modelFullname" -}}
{{- printf "%s-%s" (include "azimuth-inference.fullname" .root) .model.name -}}
{{- end }}

{{- define "azimuth-inference.modelSelectorLabels" -}}
{{ include "azimuth-inference.selectorLabels" .root }}
azimuth.stackhpc.com/inference-model: {{ .model.name }}
{{- end }}

{{- define "azimuth-inference.modelLabels" -}}
{{ include "azimuth-inference.labels" .root }}
azimuth.stackhpc.com/inference-model: {{ .model.name }}
{{- end }}

{{- define "azimuth-inference.modelProfile" -}}
{{- $profile := index .root.Values.profiles .model.profile -}}
{{- required (printf "unknown inference profile %q" .model.profile) $profile | toYaml -}}
{{- end }}

{{- define "azimuth-inference.modelAlias" -}}
{{- $profile := include "azimuth-inference.modelProfile" . | fromYaml -}}
{{- default (required "profile must set modelAlias" $profile.modelAlias) .model.modelAlias -}}
{{- end }}

{{- define "azimuth-inference.modelDir" -}}
/srv/inference/models/gguf
{{- end }}

{{- define "azimuth-inference.modelPath" -}}
{{- $profile := include "azimuth-inference.modelProfile" . | fromYaml -}}
{{- printf "%s/%s" (include "azimuth-inference.modelDir" .root) (required "profile must set modelFile" $profile.modelFile) -}}
{{- end }}

{{- define "azimuth-inference.mmprojPath" -}}
{{- $profile := include "azimuth-inference.modelProfile" . | fromYaml -}}
{{- with $profile.mmprojFile -}}
{{- printf "%s/%s" (include "azimuth-inference.modelDir" $) . -}}
{{- end -}}
{{- end }}

{{- define "azimuth-inference.modelArtifacts" -}}
{{- $profile := include "azimuth-inference.modelProfile" . | fromYaml -}}
{{- $artifacts := list (dict
      "file" (required "profile must set modelFile" $profile.modelFile)
      "url" (required "profile must set modelUrl" $profile.modelUrl)
      "sha256" (required "profile must set sha256" $profile.sha256)
) -}}
{{- if or $profile.mmprojFile $profile.mmprojUrl $profile.mmprojSha256 -}}
{{- $artifacts = append $artifacts (dict
      "file" (required "a profile with a vision projector must set mmprojFile" $profile.mmprojFile)
      "url" (required "a profile with a vision projector must set mmprojUrl" $profile.mmprojUrl)
      "sha256" (required "a profile with a vision projector must set mmprojSha256" $profile.mmprojSha256)
) -}}
{{- end -}}
{{- if and (hasKey $profile "noMmprojOffload") (not $profile.mmprojFile) -}}
{{- fail "profile sets noMmprojOffload but no mmprojFile: there is no projector to keep out of VRAM, so the setting would be silently ignored" -}}
{{- end -}}
{{- toYaml (dict "artifacts" $artifacts) -}}
{{- end }}

{{- define "azimuth-inference.gpuResourceName" -}}
{{- $profile := include "azimuth-inference.modelProfile" . | fromYaml -}}
{{- default "nvidia.com/gpu" $profile.gpuResourceName -}}
{{- end }}

{{- define "azimuth-inference.gpuCount" -}}
{{- $profile := include "azimuth-inference.modelProfile" . | fromYaml -}}
{{- required "profile must set gpuCount" $profile.gpuCount -}}
{{- end }}

{{- define "azimuth-inference.modelNodeSelector" -}}
{{- $scheduling := .model.scheduling -}}
{{- $selector := dict -}}
{{- with $scheduling.azimuthNodeGroupSelector -}}
{{- $_ := set $selector "capi.stackhpc.com/node-group" . -}}
{{- end -}}
{{- if $scheduling.requireGpuNode -}}
{{- $_ := set $selector "nvidia.com/gpu.present" "true" -}}
{{- end -}}
{{- with $scheduling.nodeSelector -}}
{{- $selector = merge $selector . -}}
{{- end -}}
{{- if $selector -}}
{{- toYaml $selector -}}
{{- end -}}
{{- end }}

{{- define "azimuth-inference.modelAliases" -}}
{{- $models := .Values.models -}}
{{- $profiles := .Values.profiles -}}
{{- $aliases := list -}}
{{- range $model := $models -}}
  {{- $profile := index $profiles $model.name -}}
  {{- if and $profile $profile.modelAlias -}}
    {{- $aliases = append $aliases $profile.modelAlias -}}
  {{- end -}}
{{- end -}}
{{- $aliases | toJson -}}
{{- end -}}
