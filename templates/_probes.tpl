{{/*
Render a probe map with EXACTLY ONE handler and no null keys.

Why: helm's cross-layer value merge cannot reliably DELETE a base handler when
an override adds a different handler type (null-through-subchart coalesce —
observed 2026-07-04: mcp-proxy defaults exec probes, the mcp-grafana app
overrode with httpGet, the rendered pod spec carried BOTH -> Pod invalid,
StatefulSet FailedCreate for 63 days). This helper makes handler switching
safe: when multiple handlers survive the merge, priority is
httpGet > tcpSocket > grpc > exec; nil-valued keys are dropped.
*/}}
{{- define "k8s-service-template.sanitizeProbe" -}}
{{- $probe := . -}}
{{- $handlers := list "httpGet" "tcpSocket" "grpc" "exec" -}}
{{- $out := dict -}}
{{- range $k, $v := $probe -}}
{{- if and (not (has $k $handlers)) (not (kindIs "invalid" $v)) -}}
{{- $_ := set $out $k $v -}}
{{- end -}}
{{- end -}}
{{- $chosen := "" -}}
{{- range $h := $handlers -}}
{{- if and (eq $chosen "") (hasKey $probe $h) -}}
{{- $v := get $probe $h -}}
{{- if not (kindIs "invalid" $v) -}}
{{- $chosen = $h -}}
{{- $_ := set $out $h $v -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}
