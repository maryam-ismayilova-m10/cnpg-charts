{{- define "cluster.bootstrap" -}}
{{- if eq .Values.mode "standalone" }}
bootstrap:
  initdb:
    {{- with .Values.cluster.initdb }}
        {{- with (omit . "postInitApplicationSQL" "owner" "import") }}
            {{- . | toYaml | nindent 4 }}
        {{- end }}
    {{- end }}
    {{- if .Values.cluster.initdb.owner }}
    owner: {{ tpl .Values.cluster.initdb.owner . }}
    {{- end }}
    {{- if or (eq .Values.type "postgis") (eq .Values.type "timescaledb") (not (empty .Values.cluster.initdb.postInitApplicationSQL)) }}
    postInitApplicationSQL:
      {{- if eq .Values.type "postgis" }}
      - CREATE EXTENSION IF NOT EXISTS postgis;
      - CREATE EXTENSION IF NOT EXISTS postgis_topology;
      - CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
      - CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
      {{- else if eq .Values.type "timescaledb" }}
      - CREATE EXTENSION IF NOT EXISTS timescaledb;
      {{- end }}
      {{- with .Values.cluster.initdb }}
          {{- range .postInitApplicationSQL }}
            {{- printf "- %s" . | nindent 6 }}
          {{- end -}}
      {{- end -}}
    {{- end }}
{{- else if eq .Values.mode "recovery" -}}
bootstrap:
{{- if eq .Values.recovery.method "pg_basebackup" }}
  pg_basebackup:
    source: pgBaseBackupSource
    {{ with .Values.recovery.pgBaseBackup.database }}
    database: {{ . }}
    {{- end }}
    {{ with .Values.recovery.pgBaseBackup.owner }}
    owner: {{ . }}
    {{- end }}
    {{ with .Values.recovery.pgBaseBackup.secret }}
    secret:
      {{- toYaml . | nindent 6 }}
    {{- end }}

externalClusters:
  {{- include "cluster.externalSourceCluster" (list "pgBaseBackupSource" .Values.recovery.pgBaseBackup.source) | nindent 2 }}

{{- else if eq .Values.recovery.method "import" }}
  initdb:
    {{- with .Values.cluster.initdb }}
        {{- with (omit . "owner" "import") }}
            {{- . | toYaml | nindent 4 }}
        {{- end }}
    {{- end }}
    {{- if .Values.cluster.initdb.owner }}
    owner: {{ tpl .Values.cluster.initdb.owner . }}
    {{- end }}
    import:
      source:
        externalCluster: importSource
      type: {{ .Values.recovery.import.type }}
      databases: {{ .Values.recovery.import.databases | toJson }}
      {{ with .Values.recovery.import.roles }}
      roles: {{ . | toJson }}
      {{- end }}
      {{ with .Values.recovery.import.postImportApplicationSQL }}
      postImportApplicationSQL:
        {{- . | toYaml | nindent 6 }}
      {{- end }}
      schemaOnly: {{ .Values.recovery.import.schemaOnly }}
      {{ with .Values.recovery.import.pgDumpExtraOptions }}
      pgDumpExtraOptions:
        {{- . | toYaml | nindent 6 }}
      {{- end }}
      {{ with .Values.recovery.import.pgRestoreExtraOptions }}
      pgRestoreExtraOptions:
        {{- . | toYaml | nindent 6 }}
      {{- end }}

externalClusters:
  {{- include "cluster.externalSourceCluster" (list "importSource" .Values.recovery.import.source) | nindent 2 }}

{{- else }}
  recovery:
    {{- with .Values.recovery.pitrTarget.time }}
    recoveryTarget:
      targetTime: {{ . }}
    {{- end }}
    {{ with .Values.recovery.database }}
    database: {{ . }}
    {{- end }}
    {{ with .Values.recovery.owner }}
    owner: {{ . }}
    {{- end }}
    {{- if eq .Values.recovery.method "backup" }}
    backup:
      name: {{ .Values.recovery.backupName }}
    {{- else if eq .Values.recovery.method "object_store" }}
    source: objectStoreRecoveryCluster

externalClusters:
  - name: objectStoreRecoveryCluster
    barmanObjectStore:
      serverName: {{ .Values.recovery.clusterName }}
      {{- $d := dict "chartFullname" (include "cluster.fullname" .) "scope" .Values.recovery "secretPrefix" "recovery" -}}
      {{- include "cluster.barmanObjectStoreConfig" $d | nindent 4 }}
    {{- end }}
{{- end }}

{{- else if eq .Values.mode "replica" -}}
bootstrap:
{{- if eq .Values.replica.bootstrapMethod "pg_basebackup" }}
  pg_basebackup:
    source: {{ coalesce .Values.replica.remoteCluster.name  "remote" }}
    {{- with .Values.cluster.initdb.database }}
    database: {{ . }}
    {{- end }}
    {{- with .Values.cluster.initdb.owner }}
    owner: {{ . }}
    {{- end }}
    {{- with .Values.cluster.initdb.secret }}
    secret:
      {{- toYaml . | nindent 6 }}
    {{- end }}
{{- if eq .Values.replica.bootstrapMethod "objectStore" }}
  recovery:
    source: {{ coalesce .Values.replica.remoteCluster.name  "remote" }}
    {{- with .Values.cluster.initdb.database }}
    database: {{ . }}
    {{- end }}
    {{- with .Values.cluster.initdb.owner }}
    owner: {{ . }}
    {{- end }}
    {{- with .Values.cluster.initdb.secret }}
    secret:
      {{- toYaml . | nindent 6 }}
    {{- end }}
{{- else -}}
  {{fail "Invalid replica bootstrap method!" }}
{{- end }}

replica:
  source: {{ coalesce .Values.replica.remoteCluster.name  "remote" }}

{{- if eq .Values.replica.mode "standalone" }}
  enabled: {{ .Values.replica.enabled }}
{{- end }}
{{- if eq .Values.replica.mode "distributed" }}
  self: {{ coalesce .Values.replica.localCluster.name  "local" }}
  {{- if not .Values.replica.primaryCluster }}
    {{ fail "replica.primaryCluster must be set when replica.mode is distributed" }}
  {{- else }}
  primary: {{ .Values.replica.primaryCluster }}
  {{- end }}
{{- end }}  
  
  {{- with .Values.replica.promotionToken }}
  promotionToken: {{ . }}
  {{- end }}

  {{- with .Values.replica.minApplyDelay }}
  minApplyDelay: {{ . }}
  {{- end }}


externalClusters:
  {{- if or (not .Values.replica.mode) (eq .Values.replica.mode "standalone") }}
    {{- include "cluster.externalCluster" (list (coalesce .Values.replica.remoteCluster.name  "remote") .Values.replica.remoteCluster.source ) | nindent 2 }}
  {{- else if eq .Values.replica.mode "distributed" }}
    {{- fail "Distributed mode is not supported by this chart yet" }}
    {{- include "cluster.externalCluster" (list (coalesce .Values.replica.remoteCluster.name  "remote") .Values.replica.remoteCluster.source ) | nindent 2 }}
    {{- include "cluster.externalCluster" (list (coalesce .Values.replica.localCluster.name  "local") .Values.replica.localCluster.source ) | nindent 2 }}
  {{- else }}
    {{ fail "Invalid replica mode!" }}
  {{- end }}

{{-  else }}
  {{ fail "Invalid cluster mode!" }}
{{- end }}
{{- end }}
