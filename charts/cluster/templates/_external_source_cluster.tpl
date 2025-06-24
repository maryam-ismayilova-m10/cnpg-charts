{{- define "cluster.externalSourceCluster" -}}
{{- $name := first . -}}
{{- $config := last . -}}
- name: {{ first . }}
  connectionParameters:
    host: {{ $config.host | quote }}
    port: {{ $config.port | quote }}
    user: {{ $config.username | quote }}
    {{- with $config.database }}
    dbname: {{ . | quote }}
    {{- end }}
    sslmode: {{ $config.sslMode | quote }}
  {{- if $config.passwordSecret.name }}
  password:
    name: {{ $config.passwordSecret.name }}
    key: {{ $config.passwordSecret.key }}
  {{- end }}
  {{- if $config.sslKeySecret.name }}
  sslKey:
    name: {{ $config.sslKeySecret.name }}
    key: {{ $config.sslKeySecret.key }}
  {{- end }}
  {{- if $config.sslCertSecret.name }}
  sslCert:
    name: {{ $config.sslCertSecret.name }}
    key: {{ $config.sslCertSecret.key }}
  {{- end }}
  {{- if $config.sslRootCertSecret.name }}
  sslRootCert:
    name: {{ $config.sslRootCertSecret.name }}
    key: {{ $config.sslRootCertSecret.key }}
  {{- end }}
{{- end }}

{{- define "cluster.externalCluster" -}}
{{- $name := first . -}}
{{- $config := last . -}}
{{- $streamingConfig := $config.streaming -}}
{{- $s3Config := $config.objectStore -}}
- name: {{ first . }}
  {{- if $streamingConfig.enabled }}
  connectionParameters:
    host: {{ $streamingConfig.host | quote }}
    port: {{ $streamingConfig.port | quote }}
    user: {{ $streamingConfig.username | quote }}
    {{- with $streamingConfig.database }}
    dbname: {{ . | quote }}
    {{- end }}
    sslmode: {{ $streamingConfig.sslMode | quote }}
  {{- if $streamingConfig.passwordSecret.name }}
  password:
    name: {{ $streamingConfig.passwordSecret.name }}
    key: {{ $streamingConfig.passwordSecret.key }}
  {{- end }}
  {{- if $streamingConfig.sslKeySecret.name }}
  sslKey:
    name: {{ $streamingConfig.sslKeySecret.name }}
    key: {{ $streamingConfig.sslKeySecret.key }}
  {{- end }}
  {{- if $streamingConfig.sslCertSecret.name }}
  sslCert:
    name: {{ $streamingConfig.sslCertSecret.name }}
    key: {{ $streamingConfig.sslCertSecret.key }}
  {{- end }}
  {{- if $streamingConfig.sslRootCertSecret.name }}
  sslRootCert:
    name: {{ $streamingConfig.sslRootCertSecret.name }}
    key: {{ $streamingConfig.sslRootCertSecret.key }}
  {{- end }}
  {{- end }}
  
  {{- if $s3Config.enabled }}
  barmanObjectStore:
    serverName: {{ coalesce $s3Config.serverName  $config.clusterName $name }}
    {{- $d := dict "chartFullname" (coalesce $s3Config.serverName  $config.clusterName $name) "scope" $s3Config "secretPrefix" "replica" -}}
    {{- include "cluster.barmanObjectStoreConfig" $d | nindent 2 }}
  {{- end }}

{{- end }}