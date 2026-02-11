{{/*
This file contains helper functions for the mina-standard-node chart.

All special templates stem from the *.plain.* variants.
*/}}

{{/*
  "mina-standard-node.plain.image": provides the image name and tag.
*/}}
{{- define "mina-standard-node.plain.image" }}
{{- $root := .root.Values }}
{{- $image := $root.common.daemon.image }}
{{- if and (hasKey .node.values.daemon "image") (.node.values.daemon.image) }}
{{- $image = .node.values.daemon.image }}
{{- end }}
{{ toYaml $image }}
{{- end -}}


{{/*
  "mina-standard-node.plain.secrets": provides a list of secrets.
  Also, fetches secrets from GCP Secret Manager if label 'gcp: *' is set.
*/}}
{{- define "mina-standard-node.plain.secrets" -}}
{{- $secretsList := list }}
{{- $secretsAnnotations := dict }}
{{- if .node.values.secrets }}
  {{- if hasKey .node.values.secrets "secrets" }}
    {{/* Handle nested structure: secrets: { secrets: [...], secretsAnnotations: {...} } */}}
    {{- $secretsList = .node.values.secrets.secrets }}
    {{- if hasKey .node.values.secrets "secretsAnnotations" }}
      {{- $secretsAnnotations = .node.values.secrets.secretsAnnotations }}
    {{- end }}
  {{- else if kindIs "slice" .node.values.secrets }}
    {{/* Handle flat structure: secrets: [...] */}}
    {{- $secretsList = .node.values.secrets }}
  {{- end }}
{{- end }}
{{- if $secretsAnnotations }}
secretsAnnotations:
{{- toYaml $secretsAnnotations | indent 2 }}
{{- end }}
{{- if $secretsList }}
secrets:
  {{- range $secretsList }}
  - name: {{ .name }}
    {{- $labels := dict }}
    {{- if hasKey . "labels" }}
    {{- $labels = .labels }}
    labels:
      {{ toYaml $labels | indent 6 }}
    {{- end }}
    data:
    {{- range $key, $val := .data }}
    {{- if hasKey $labels "gcp" }}
      {{ $key }}: {{ $val | fetchSecretValue | trim | quote }}
    {{ else }}
      {{ $key }}: {{ $val | trim | quote }}
    {{- end }}
    {{- end }}
    {{- end }}
{{- else }}
secrets: []
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.plain.ports": merges common and per-node ports, outputs
  list of values.
*/}}
{{- define "mina-standard-node.plain.ports" -}}
{{- $root := .root.Values }}
{{- $ports := merge .node.values.daemon.ports $root.common.daemon.ports }}
{{- range $key, $val := $ports }}
{{ toYaml ($val | list) }}
{{- end }}
{{- end -}}

{{/*
  "mina-standard-node.plain.network": provides the network name.
  Defaults to the global network value, but any node-level configuration
  over-writes this.
*/}}
{{- define "mina-standard-node.plain.network" -}}
{{- $network := merge .node.values.daemon .root.Values.global -}}
{{ $network.network }}
{{- end -}}


{{/*
  "mina-standard-node.plain.extraArgs": provides a list of extra arguments.
*/}}
{{- define "mina-standard-node.plain.extraArgs" -}}
{{- if eq (printf "%v" .node.values.daemon.init.enable) "true" }}
{{/* Adding args to reference genesis config */}}
{{- $genesisFile := "genesis-config.json" }}
{{- if hasKey (((.node.values.daemon.init).genesis).secret) "key" -}}
{{- $genesisFile = (printf "%s" .node.values.daemon.init.genesis.secret.key) }}
{{- end }}
{{- if eq (printf "%v" .node.values.daemon.init.genesis.skip) "false" }}
- -config-file
- /root/.mina-config/{{ $genesisFile }}
{{- end }}
{{- end }}
{{- range .node.values.daemon.extraArgs }}
- {{ . | quote }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.plain.env": provides a list of required environment variables.
  These are coupled to required daemon ports. For archive role none of these are added.
*/}}
{{- define "mina-standard-node.plain.env" -}}
{{- $root := .root.Values }}
{{- if not (has (printf "%s" .node.role) (list "archive" "minarustseed")) }}
{{- $ports := merge .node.values.daemon.ports $root.common.daemon.ports }}
{{- $metricsPort := index $ports "metrics" }}
{{- if $metricsPort }}
- name: DAEMON_METRICS_PORT
  value: {{ $metricsPort.containerPort | quote }} 
{{- end }}
{{- $graphqlPort := index $ports "graphql" }}
{{- if $graphqlPort }}
- name: DAEMON_REST_PORT
  value: {{ $graphqlPort.containerPort | quote }}
{{- end }}
{{- $clientPort := index $ports "client" }}
{{- if $clientPort }}
- name: DAEMON_CLIENT_PORT
  value: {{ $clientPort.containerPort | quote }}
{{- end }}
{{- $externalPort := index $ports "external" }}
{{- if $externalPort }}
- name: DAEMON_EXTERNAL_PORT
  value: {{ $externalPort.containerPort | quote }}
{{- end }}
- name: NETWORK_NAME
  value: {{ .node.values.daemon.network | quote }}
- name: MINA_LIBP2P_PASS
  {{- $libp2pPwd := "" }}
  {{- if .node.values.daemon.init.enable }}
  {{- $libp2pPwd = .node.values.daemon.init.libp2pKeys.password | quote }}
  {{- end }}
  value: {{ $libp2pPwd }}
- name: MINA_PRIVKEY_PASS
  {{- $privkeyPwd := "" }}
  {{- if .node.values.daemon.init.enable }}
  {{- $privkeyPwd = .node.values.daemon.init.keys.password | quote }}
  {{- end }}
  value: {{ $privkeyPwd }}
{{- end }}
{{- $env := merge .node.values.daemon.env $root.common.daemon.env }}
{{- range $key, $val := $env }}
- name: {{ $key }}
  value: {{ $val | quote }}
{{- end }}
{{/* Adding envs from existing Secrets */}}
{{- $envFromSecretList := concat $root.common.daemon.envFromSecret .node.values.daemon.envFromSecret }}
{{- range $envFromSecretList }}
- name: {{ .name }}
  valueFrom:
    secretKeyRef:
      name: {{ .secretKeyRef.name }}
      key: {{ .secretKeyRef.key }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.standard.env": provides a list of environment variables.
  This is used on roles that do not require particular daemon configurations, e.g., rosetta
*/}}
{{- define "mina-standard-node.standard.env" -}}
{{- $root := .root.Values }}
{{- $env := merge .node.values.daemon.env $root.common.daemon.env }}
{{- range $key, $val := $env }}
- name: {{ $key }}
  value: {{ $val | quote }}
{{- end }}
{{/* Adding envs from existing Secrets */}}
{{- $envFromSecretList := concat $root.common.daemon.envFromSecret .node.values.daemon.envFromSecret }}
{{- range $envFromSecretList }}
- name: {{ .name }}
  valueFrom:
    secretKeyRef:
      name: {{ .secretKeyRef.name }}
      key: {{ .secretKeyRef.key }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.plain.volumes": provides a list of required volumes.
*/}}
{{- define "mina-standard-node.plain.volumes" -}}
{{- $isArchive := eq .node.role "archive" }}
{{- with .node.values.daemon.init }}
{{- if .enable }}
- name: wallet-keys
  emptyDir: {}
{{- if .keys.fromSecret }}
- name: private-keys
  secret:
    secretName: {{ .keys.secret.name }}
    defaultMode: 256
    items:
    - key: key
      path: key
    - key: pub
      path: key.pub
{{- end }}
{{- if .genesis.fromSecret }}
- name: {{ .genesis.secret.name }}
  secret:
    secretName: {{ .genesis.secret.name }}
    defaultMode: 0644
{{- end }}
{{- if .genesis.fromValue }}
- name: genesis-inline-config
  configMap:
    name: {{ printf "%s-genesis-config" $.node.name }}
    defaultMode: 0644
    items:
    - key: {{ .genesis.value.filename }}
      path: {{ .genesis.value.filename }}
{{- end }}
{{- if .libp2pKeys.fromSecret }}
- name: libp2p-keys
  secret:
    secretName: {{ .libp2pKeys.secret.name }}
    defaultMode: 448
    items:
    - key: key
      path: key
    - key: pub
      path: key.pub
{{- end }}
{{- end }}
{{- end }}
{{- if not $isArchive }}
- name: actual-libp2p
  emptyDir: {}
{{- end }}
{{/* Configuration directory */}}
- name: config-dir
{{- if .node.values.daemon.persistence.enable }}
  persistentVolumeClaim:
    claimName: {{ .node.name }}
{{- else }}
  emptyDir: {}
{{- end }}
{{- with .root.Values.common.volumes }}
{{ toYaml . }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.plain.volumeMounts": provides a list of required volume mounts.
  Archive node requires only one of daemon's volumeMounts.
*/}}
{{- define "mina-standard-node.plain.volumeMounts" -}}
{{- if ne .node.role "archive" }}
- mountPath: /root/libp2p-keys
  name: actual-libp2p
{{- with .node.values.daemon.init }}
{{- if .enable }}
- mountPath: /root/wallet-keys
  name: wallet-keys
{{- end }}
{{- end }}
{{- end }}
- mountPath: /root/.mina-config/
  name: config-dir
{{- with .root.Values.common.daemon.volumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
  "mina-standard-node.plain.initContainers": defines initContainers for daemon.
  It calls other "sub" templates to generate the required configuration.
*/}}
{{- define "mina-standard-node.plain.initContainers" -}}
{{- if .node.values.daemon.init.enable }}
{{- include "mina-standard-node.plain.initContainers.copyKeys" . }}
{{ include "mina-standard-node.plain.initContainers.installKeys" . }}
{{- if (ne (printf "%v" .node.values.daemon.init.libp2pKeys.skip) "true") }}
{{ include "mina-standard-node.plain.initContainers.libp2p" . }}
{{- end }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.plain.initContainers.copyKeys": copies keys from the keys
  directory to the wallet-keys directory.
*/}}
{{- define "mina-standard-node.plain.initContainers.copyKeys" }}
- name: fix-perms
  image:
    repository: busybox
    tag: 1.37.0
  command: ["sh", "-c"]
  args:
    - |
      #!/usr/bin/env sh
      
      set -xe;
      for dir in keys echo-keys faucet-keys; do 
        [ -d /root/$dir ] && /bin/cp /root/$dir/* /root/wallet-keys; 
      done;

      /bin/chmod 0700 /root/wallet-keys;
      /bin/chmod -R 0777 /root/.mina-config

      cp /root/genesis/* /root/.mina-config/ || true;
      cp /root/genesis-inline/* /root/.mina-config/ || true;
  volumeMounts:
  - name: wallet-keys
    mountPath: /root/wallet-keys
  - name: config-dir
    mountPath: /root/.mina-config
  {{- if .node.values.daemon.init.genesis.fromSecret }}
  - name: {{ .node.values.daemon.init.genesis.secret.name }}
    mountPath: /root/genesis
    readOnly: true
  {{- end }}
  {{- if .node.values.daemon.init.genesis.fromValue }}
  - name: genesis-inline-config
    mountPath: /root/genesis-inline
    readOnly: true
  {{- end }}
  {{- if .node.values.daemon.init.keys.fromSecret }}
  - name: private-keys
    mountPath: /root/keys
  {{- end }}
  resources:
    requests:
      cpu: 300m
      memory: 100Mi
    limits:
      cpu: 1
      memory: 1Gi
  securityContext:
    runAsUser: 0
{{- end -}}


{{/*
  "mina-standard-node.plain.initContainers.installKeys": imports keys into the mina daemon.
*/}}
{{- define "mina-standard-node.plain.initContainers.installKeys" -}}
- name: install-key
  image:
  {{- $imageObj := .root.Values.common.daemon.image }}
  {{- if and (hasKey .node.values.daemon "image") (.node.values.daemon.image) }}
  {{- $imageObj = .node.values.daemon.image }}
  {{- end }}
  {{- if and (hasKey .node.values.daemon.init "image") (.node.values.daemon.init.image) }}
  {{- $imageObj = .node.values.daemon.init.image }}
  {{- end }}
  {{- toYaml $imageObj | nindent 4 }}
  command: ["bash", "-c"]
  args:
    - |
      #!/usr/bin/env bash
      
      set -xe;
      for key in key echo-key faucet-key; do 
        [ ! -f /root/wallet-keys/$key ] || mina accounts import -config-directory /root/.mina-config -privkey-path /root/wallet-keys/$key; 
      done;
  volumeMounts:
  - name: wallet-keys
    mountPath: /root/wallet-keys
  - name: config-dir
    mountPath: /root/.mina-config
  env:
    - name: MINA_PRIVKEY_PASS
      value: {{ .node.values.daemon.init.keys.password | quote }}
  resources:
    requests:
      cpu: 300m
      memory: 100Mi
    limits:
      cpu: 1
      memory: 1Gi
{{- end -}}


{{/*
  "mina-standard-node.plain.initContainers.libp2p": generates libp2p keys.
*/}}
{{- define "mina-standard-node.plain.initContainers.libp2p" -}}
- name: libp2p-perms
  image:
  {{- $imageObj := .root.Values.common.daemon.image }}
  {{- if and (hasKey .node.values.daemon "image") (.node.values.daemon.image) }}
  {{- $imageObj = .node.values.daemon.image }}
  {{- end }}
  {{- if and (hasKey .node.values.daemon.init "image") (.node.values.daemon.init.image) }}
  {{- $imageObj = .node.values.daemon.init.image }}
  {{- end }}
  {{- toYaml $imageObj | nindent 4 }}
  command: ["bash", "-c"]
  args:
    - |
      #!/usr/bin/env bash

      set -xe;

      # Check if lip2p keys from secret directory exist,
      # if it does not exist, generate new keys.
      if [ ! -d /libp2p-keys-from-secret ]; then
        mina libp2p generate-keypair --privkey-path /root/libp2p-keys/key;
      else
        # Copy keys from secret directory to the actual libp2p keys directory.
        /bin/cp /libp2p-keys-from-secret/* /root/libp2p-keys;
      fi

      /bin/chmod -R 0700 /root/libp2p-keys/;
  volumeMounts:
  - name: actual-libp2p
    mountPath: /root/libp2p-keys
  {{- if .node.values.daemon.init.libp2pKeys.fromSecret }}
  - name: libp2p-keys
    mountPath: /libp2p-keys-from-secret
  {{- end }}
  env:
  - name: MINA_LIBP2P_PASS
    value: {{ .node.values.daemon.init.libp2pKeys.password | quote }}
  resources:
    requests:
      cpu: 300m
      memory: 100Mi
    limits:
      cpu: 1
      memory: 1Gi
{{- end -}}


{{/*
  "mina-standard-node.plain.service": provides the service definition.
  Services are created according to defined ports. Default port is the external.
  Others are added as externalPorts.
*/}}
{{- define "mina-standard-node.plain.service" -}}
{{- $root := .root.Values }}
{{- $ports := merge .node.values.daemon.ports $root.common.daemon.ports }}
{{- $serviceType := "ClusterIP" }}
{{- $annotations := dict }}
{{- if hasKey .node.values.daemon "service" }}
{{- with .node.values.daemon.service }}
{{- if hasKey . "type" }}
{{- $serviceType = .type }}
{{- end }}
{{- if hasKey . "annotations" }}
{{- $annotations = .annotations }}
{{- end }}
{{- end }}
{{- end }}
enable: {{ if hasKey . "enable" }}{{ . }}{{ else }}true{{ end }}
type: {{ $serviceType }}
annotations:
  {{- toYaml $annotations | nindent 2 }}
port: {{ $ports.external.containerPort }}
targetPort: {{ $ports.external.name }}
protocol: {{ $ports.external.protocol }}
{{- $extraPorts := omit $ports "external" }}
extraPorts:
{{- range $key, $val := $extraPorts }}
- name: {{ $val.name }}
  annotations:
    {{- if hasKey $val "annotations" }}
    {{- toYaml $val.annotations | nindent 4 }}
    {{- end }}
  port: {{ $val.containerPort }}
  targetPort: {{ $val.name }}
  protocol: {{ $val.protocol }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.plain.tolerations": provides a list of tolerations.
*/}}
{{- define "mina-standard-node.plain.tolerations" -}}
{{- $root := .root.Values }}
{{- $tolerations := $root.common.tolerations | default list}}
{{- if hasKey .node.values "tolerations" }}
{{- $tolerations = concat $tolerations .node.values.tolerations }}
{{- end }}
{{ toYaml $tolerations }}
{{- end -}}


{{/*
  "mina-standard-node.plain.affinity": provides a list of tolerations.
*/}}
{{- define "mina-standard-node.plain.affinity" -}}
{{- $root := .root.Values }}
{{- $affinity := $root.common.affinity | default dict }}
{{- if hasKey .node.values "affinity" }}
{{- $affinity = merge .node.values.affinity $affinity }}
{{- end }}
{{ toYaml $affinity }}
{{- end -}}


{{/*
  "mina-standard-node.plain.persistentVolumeClaim": provides a persistent volume claim.
*/}}
{{- define "mina-standard-node.plain.persistentVolumeClaim" -}}
{{- $persistence := .node.values.daemon.persistence }}
enable: {{ $persistence.enable }}
{{- if $persistence.enable }}
{{- with $persistence.annotations }}
annotations:
{{ toYaml . | indent 2 }}
{{- end }}
storageClassName: {{ $persistence.claim.storageClassName }}
size: {{ $persistence.claim.size }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.standard.ports": merges common and per-node ports, outputs list of values.
*/}}
{{- define "mina-standard-node.standard.ports" -}}
{{- $root := .root.Values }}
{{- $ports := .node.values.daemon.ports }}
{{- range $key, $val := $ports }}
{{ toYaml ($val | list) }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.rosetta.ports": merges common and per-node ports, outputs list of values.
*/}}
{{- define "mina-standard-node.rosetta.ports" -}}
{{- $root := .root.Values }}
{{- $ports := .node.values.daemon.ports }}
{{- range $key, $val := $ports }}
{{ toYaml ($val | list) }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.rosetta.service": provides the service definition.
  Services are created according to defined ports. Default port is rosetta.
  Others are added as externalPorts.
*/}}
{{- define "mina-standard-node.rosetta.service" -}}
{{- $root := .root.Values }}
{{- $ports := .node.values.daemon.ports }}
{{- $serviceType := "ClusterIP" }}
{{- $annotations := dict }}
{{- if hasKey .node.values.daemon "service" }}
{{- with .node.values.daemon.service }}
{{- if hasKey . "type" }}
{{- $serviceType = .type }}
{{- end }}
{{- if hasKey . "annotations" }}
{{- $annotations = .annotations }}
{{- end }}
{{- end }}
{{- end }}
enable: {{ if hasKey . "enable" }}{{ . }}{{ else }}true{{ end }}
type: {{ $serviceType }}
annotations:
  {{- toYaml $annotations | nindent 2 }}
{{- $rosettaPort := index $ports "rosetta" }}
{{- if $rosettaPort }}
port: {{ $rosettaPort.containerPort }}
targetPort: {{ $rosettaPort.name }}
protocol: {{ $rosettaPort.protocol }}
{{- $extraPorts := omit $ports "rosetta" }}
extraPorts:
{{- range $key, $val := $extraPorts }}
- name: {{ $val.name }}
  annotations:
    {{- if hasKey $val "annotations" }}
    {{- toYaml $val.annotations | nindent 4 }}
    {{- end }}
  port: {{ $val.containerPort }}
  targetPort: {{ $val.name }}
  protocol: {{ $val.protocol }}
{{- end }}
{{- else }}
{{- fail "Rosetta port configuration is required for rosetta service" }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.minarustbp.initContainers": Init container for producer key generation
*/}}
{{- define "mina-standard-node.minarustbp.initContainers" -}}
{{- if .node.values.daemon.init.enable }}
{{- if .node.values.daemon.init.producerKey.generate }}
- name: generate-producer-key
  image:
  {{- $imageObj := .root.Values.common.daemon.image }}
  {{- if and (hasKey .node.values.daemon "image") (.node.values.daemon.image) }}
  {{- $imageObj = .node.values.daemon.image }}
  {{- end }}
  {{- if and (hasKey .node.values.daemon.init "image") (.node.values.daemon.init.image) }}
  {{- $imageObj = .node.values.daemon.init.image }}
  {{- end }}
  {{- toYaml $imageObj | nindent 4 }}
  command: ["bash", "-c"]
  args:
    - |
      #!/usr/bin/env bash

      set -euo pipefail

      echo "Setting up producer key..."

      {{- if .node.values.daemon.persistence.enable }}
      # With persistence: store keys in /data/keys/ and copy to runtime location
      PERSISTENT_KEY_DIR="/data/keys"
      PERSISTENT_KEY_PATH="$PERSISTENT_KEY_DIR/producer-key"
      RUNTIME_KEY_DIR="/root/.mina"
      RUNTIME_KEY_PATH="$RUNTIME_KEY_DIR/producer-key"

      mkdir -p "$PERSISTENT_KEY_DIR"
      mkdir -p "$RUNTIME_KEY_DIR"

      {{- if .node.values.daemon.init.producerKey.fromSecret }}
      # Copy producer key from secret to persistent storage
      if [ -f /producer-key-secret/key ]; then
        echo "Copying producer key from secret to persistent storage..."
        cp /producer-key-secret/key "$PERSISTENT_KEY_PATH"
      else
        echo "Error: Producer key not found in secret"
        exit 1
      fi
      {{- else }}
      # Check if key already exists in persistent storage
      if [ -f "$PERSISTENT_KEY_PATH" ]; then
        echo "Producer key already exists in persistent storage, reusing..."
      else
        # Generate new producer key in persistent storage
        echo "Generating new producer key in persistent storage..."
        mina misc mina-encrypted-key "$MINA_PRIVKEY_PASS" --file "$PERSISTENT_KEY_PATH"
        echo "Producer key generated successfully"
      fi
      {{- end }}

      # Copy key from persistent storage to runtime location
      echo "Copying producer key to runtime location..."
      cp "$PERSISTENT_KEY_PATH" "$RUNTIME_KEY_PATH"
      chmod 600 "$RUNTIME_KEY_PATH"
      echo "Producer key copied: $PERSISTENT_KEY_PATH -> $RUNTIME_KEY_PATH"

      {{- else }}
      # Without persistence: generate directly in /root/.mina/
      mkdir -p /root/.mina

      {{- if .node.values.daemon.init.producerKey.fromSecret }}
      # Copy producer key from secret
      if [ -f /producer-key-secret/key ]; then
        echo "Copying producer key from secret..."
        cp /producer-key-secret/key /root/.mina/producer-key
        chmod 600 /root/.mina/producer-key
      else
        echo "Error: Producer key not found in secret"
        exit 1
      fi
      {{- else }}
      # Generate new producer key (ephemeral)
      echo "Generating new producer key (ephemeral)..."
      mina misc mina-encrypted-key "$MINA_PRIVKEY_PASS" --file /root/.mina/producer-key
      echo "Producer key generated successfully"
      {{- end }}
      {{- end }}

      # List generated keys for verification
      ls -lh /root/.mina/
      {{- if .node.values.daemon.persistence.enable }}
      ls -lh /data/keys/
      {{- end }}
  volumeMounts:
  {{- if .node.values.daemon.persistence.enable }}
  - name: config-dir
    mountPath: /data
  {{- else }}
  - name: mina-keys
    mountPath: /root/.mina
  {{- end }}
  {{- if .node.values.daemon.init.producerKey.fromSecret }}
  - name: producer-key-secret
    mountPath: /producer-key-secret
    readOnly: true
  {{- end }}
  env:
  - name: MINA_PRIVKEY_PASS
    value: {{ .node.values.daemon.init.producerKey.password | quote }}
  resources:
    requests:
      cpu: 300m
      memory: 100Mi
    limits:
      cpu: 1
      memory: 1Gi
{{- end }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.minarustbp.volumes": Custom volumes for minarustbp role
*/}}
{{- define "mina-standard-node.minarustbp.volumes" -}}
{{- if .node.values.daemon.init.enable }}
{{- if .node.values.daemon.init.producerKey.generate }}
{{- if not .node.values.daemon.persistence.enable }}
{{/* Only use emptyDir for keys when persistence is disabled */}}
- name: mina-keys
  emptyDir: {}
{{- end }}
{{- if .node.values.daemon.init.producerKey.fromSecret }}
- name: producer-key-secret
  secret:
    secretName: {{ .node.values.daemon.init.producerKey.secret.name }}
    defaultMode: 0600
    items:
    - key: {{ .node.values.daemon.init.producerKey.secret.key }}
      path: key
{{- end }}
{{- end }}
{{- end }}
{{/* Configuration directory - PVC or emptyDir */}}
- name: config-dir
{{- if .node.values.daemon.persistence.enable }}
  persistentVolumeClaim:
    claimName: {{ .node.name }}
{{- else }}
  emptyDir: {}
{{- end }}
{{/* Include common volumes */}}
{{- with .root.Values.common.volumes }}
{{ toYaml . }}
{{- end }}
{{/* Include daemon-specific volumes */}}
{{- with .node.values.daemon.volumes }}
{{ toYaml . }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.minarustbp.volumeMounts": Custom volume mounts for minarustbp role
*/}}
{{- define "mina-standard-node.minarustbp.volumeMounts" -}}
{{- if .node.values.daemon.persistence.enable }}
{{/* With persistence: mount PVC at /data for init, and /root/.mina for runtime keys */}}
- mountPath: /data
  name: config-dir
- mountPath: /root/.mina
  name: config-dir
  subPath: keys
- mountPath: /root/.mina-config/
  name: config-dir
  subPath: config
{{- else }}
{{/* Without persistence: separate mounts for keys and config */}}
{{- if .node.values.daemon.init.enable }}
{{- if .node.values.daemon.init.producerKey.generate }}
- mountPath: /root/.mina
  name: mina-keys
{{- end }}
{{- end }}
- mountPath: /root/.mina-config/
  name: config-dir
{{- end }}
{{- with .root.Values.common.daemon.volumeMounts }}
{{ toYaml . }}
{{- end }}
{{- with .node.values.daemon.volumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.minarustbp.ports": BP-specific port configuration
*/}}
{{- define "mina-standard-node.minarustbp.ports" -}}
{{- $ports := .node.values.daemon.ports }}
{{- range $key, $val := $ports }}
{{ toYaml ($val | list) }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.minarustbp.service": BP-specific service configuration
*/}}
{{- define "mina-standard-node.minarustbp.service" -}}
{{- $ports := .node.values.daemon.ports }}
{{- $serviceType := "ClusterIP" }}
{{- $annotations := dict }}
{{- if hasKey .node.values.daemon "service" }}
{{- with .node.values.daemon.service }}
{{- if hasKey . "type" }}
{{- $serviceType = .type }}
{{- end }}
{{- if hasKey . "annotations" }}
{{- $annotations = .annotations }}
{{- end }}
{{- end }}
{{- end }}
enable: true
type: {{ $serviceType }}
annotations:
  {{- toYaml $annotations | nindent 2 }}
port: {{ $ports.external.containerPort }}
targetPort: {{ $ports.external.name }}
protocol: {{ $ports.external.protocol }}
{{- $extraPorts := omit $ports "external" }}
extraPorts:
{{- range $key, $val := $extraPorts }}
- name: {{ $val.name }}
  port: {{ $val.containerPort }}
  targetPort: {{ $val.name }}
  protocol: {{ $val.protocol }}
{{- end }}
{{- end -}}


{{/*
  "mina-standard-node.minarustbp.env": Environment variables for minarustbp role
*/}}
{{- define "mina-standard-node.minarustbp.env" -}}
{{- $root := .root.Values }}
{{- $env := merge .node.values.daemon.env $root.common.daemon.env }}
{{- range $key, $val := $env }}
- name: {{ $key }}
  value: {{ $val | quote }}
{{- end }}
{{/* Adding envs from existing Secrets */}}
{{- $envFromSecretList := concat $root.common.daemon.envFromSecret .node.values.daemon.envFromSecret }}
{{- range $envFromSecretList }}
- name: {{ .name }}
  valueFrom:
    secretKeyRef:
      name: {{ .secretKeyRef.name }}
      key: {{ .secretKeyRef.key }}
{{- end }}
{{- end -}}