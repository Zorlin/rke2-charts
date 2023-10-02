{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "coredns.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "coredns.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}


{{/*
Allow k8s-app label to be overridden
*/}}
{{- define "coredns.k8sapplabel" -}}
{{- coalesce .Values.k8sApp .Values.k8sAppLabelOverride .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Generate the list of ports automatically from the server definitions
*/}}
{{- define "coredns.servicePorts" -}}
    {{/* Set ports to be an empty dict */}}
    {{- $ports := dict -}}
    {{/* Iterate through each of the server blocks */}}
    {{- range .Values.servers -}}
        {{/* Capture port to avoid scoping awkwardness */}}
        {{- $port := toString .port -}}

        {{/* If none of the server blocks has mentioned this port yet take note of it */}}
        {{- if not (hasKey $ports $port) -}}
            {{- $ports := set $ports $port (dict "istcp" false "isudp" false) -}}
        {{- end -}}
        {{/* Retrieve the inner dict that holds the protocols for a given port */}}
        {{- $innerdict := index $ports $port -}}

        {{/*
        Look at each of the zones and check which protocol they serve
        At the moment the following are supported by CoreDNS:
        UDP: dns://
        TCP: tls://, grpc://
        */}}
        {{- range .zones -}}
            {{- if has (default "" .scheme) (list "dns://") -}}
                {{/* Optionally enable tcp for this service as well */}}
                {{- if eq (default false .use_tcp) true }}
                    {{- $innerdict := set $innerdict "istcp" true -}}
                {{- end }}
                {{- $innerdict := set $innerdict "isudp" true -}}
            {{- end -}}

            {{- if has (default "" .scheme) (list "tls://" "grpc://") -}}
                {{- $innerdict := set $innerdict "istcp" true -}}
            {{- end -}}
        {{- end -}}

        {{/* If none of the zones specify scheme, default to dns:// on both tcp & udp */}}
        {{- if and (not (index $innerdict "istcp")) (not (index $innerdict "isudp")) -}}
            {{- $innerdict := set $innerdict "isudp" true -}}
            {{- $innerdict := set $innerdict "istcp" true -}}
        {{- end -}}

        {{- if .nodePort -}}
            {{- $innerdict := set $innerdict "nodePort" .nodePort -}}
        {{- end -}}

        {{/* Write the dict back into the outer dict */}}
        {{- $ports := set $ports $port $innerdict -}}
    {{- end -}}

    {{/* Write out the ports according to the info collected above */}}
    {{- range $port, $innerdict := $ports -}}
        {{- $portList := list -}}
        {{- if index $innerdict "isudp" -}}
            {{- $portList = append $portList (dict "port" ($port | int) "protocol" "UDP" "name" (printf "udp-%s" $port)) -}}
        {{- end -}}
        {{- if index $innerdict "istcp" -}}
            {{- $portList = append $portList (dict "port" ($port | int) "protocol" "TCP" "name" (printf "tcp-%s" $port)) -}}
        {{- end -}}

        {{- range $portDict := $portList -}}
            {{- if index $innerdict "nodePort" -}}
                {{- $portDict := set $portDict "nodePort" (get $innerdict "nodePort" | int) -}}
            {{- end -}}

            {{- printf "- %s\n" (toJson $portDict) -}}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Generate the list of ports automatically from the server definitions
*/}}
{{- define "coredns.containerPorts" -}}
    {{/* Set ports to be an empty dict */}}
    {{- $ports := dict -}}
    {{/* Iterate through each of the server blocks */}}
    {{- range .Values.servers -}}
        {{/* Capture port to avoid scoping awkwardness */}}
        {{- $port := toString .port -}}

        {{/* If none of the server blocks has mentioned this port yet take note of it */}}
        {{- if not (hasKey $ports $port) -}}
            {{- $ports := set $ports $port (dict "istcp" false "isudp" false) -}}
        {{- end -}}
        {{/* Retrieve the inner dict that holds the protocols for a given port */}}
        {{- $innerdict := index $ports $port -}}

        {{/*
        Look at each of the zones and check which protocol they serve
        At the moment the following are supported by CoreDNS:
        UDP: dns://
        TCP: tls://, grpc://
        */}}
        {{- range .zones -}}
            {{- if has (default "" .scheme) (list "dns://") -}}
                {{/* Optionally enable tcp for this service as well */}}
                {{- if eq (default false .use_tcp) true }}
                    {{- $innerdict := set $innerdict "istcp" true -}}
                {{- end }}
                {{- $innerdict := set $innerdict "isudp" true -}}
            {{- end -}}

            {{- if has (default "" .scheme) (list "tls://" "grpc://") -}}
                {{- $innerdict := set $innerdict "istcp" true -}}
            {{- end -}}
        {{- end -}}

        {{/* If none of the zones specify scheme, default to dns:// on both tcp & udp */}}
        {{- if and (not (index $innerdict "istcp")) (not (index $innerdict "isudp")) -}}
            {{- $innerdict := set $innerdict "isudp" true -}}
            {{- $innerdict := set $innerdict "istcp" true -}}
        {{- end -}}

        {{- if .hostPort -}}
            {{- $innerdict := set $innerdict "hostPort" .hostPort -}}
        {{- end -}}

        {{/* Write the dict back into the outer dict */}}
        {{- $ports := set $ports $port $innerdict -}}

        {{/* Fetch port from the configuration if the prometheus section exists */}}
        {{- range .plugins -}}
            {{- if eq .name "prometheus" -}}
                {{- $prometheus_addr := toString .parameters -}}
                {{- $prometheus_addr_list := regexSplit ":" $prometheus_addr -1 -}}
                {{- $prometheus_port := index $prometheus_addr_list 1 -}}
                {{- $ports := set $ports $prometheus_port (dict "istcp" true "isudp" false) -}}
            {{- end -}}
        {{- end -}}
    {{- end -}}

    {{/* Write out the ports according to the info collected above */}}
    {{- range $port, $innerdict := $ports -}}
        {{- $portList := list -}}
        {{- if index $innerdict "isudp" -}}
            {{- $portList = append $portList (dict "containerPort" ($port | int) "protocol" "UDP" "name" (printf "udp-%s" $port)) -}}
        {{- end -}}
        {{- if index $innerdict "istcp" -}}
            {{- $portList = append $portList (dict "containerPort" ($port | int) "protocol" "TCP" "name" (printf "tcp-%s" $port)) -}}
        {{- end -}}

        {{- range $portDict := $portList -}}
            {{- if index $innerdict "hostPort" -}}
                {{- $portDict := set $portDict "hostPort" (get $innerdict "hostPort" | int) -}}
            {{- end -}}

            {{- printf "- %s\n" (toJson $portDict) -}}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "coredns.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "coredns.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "system_default_registry" -}}
{{- if .Values.global.systemDefaultRegistry -}}
{{- printf "%s/" .Values.global.systemDefaultRegistry -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/*
Set the clusterDNS service IP
*/}}
{{- define "clusterDNSServerIP" -}}
{{- if .Values.service.clusterIP }}
    {{- .Values.service.clusterIP }}
{{ else }}
    {{- $dnsIPs := split "," .Values.global.clusterDNS }}
    {{- $dnsCount := len $dnsIPs }}
    {{- if eq $dnsCount 1 }}
        {{- .Values.global.clusterDNS }}
    {{- else }}
        {{- if gt $dnsCount 1 }}
            {{- $dnsIPs._0 }}
        {{ else }}
            {{- "10.43.0.10" }}
        {{- end }}
    {{- end }}
{{- end }}
{{- end }}

{{/*
Pass the clusterDNS service IP for the nodelocal config
*/}}
{{- define "nodelocalUpstreamDNSServerIP" -}}
{{- if .Values.nodelocal.ipvs }}
{{- "" -}}
{{ else }}
{{- (include "clusterDNSServerIP" .) -}}
{{- end }}
{{- end }}

{{/*
Fill the localip flag in the nodelocal CLI
*/}}
{{- define "nodelocalLocalIPFlag" -}}
{{- if .Values.nodelocal.ipvs }}
{{- "" -}}
{{ else }}
{{- printf ",%s" (include "clusterDNSServerIP" .) -}}
{{- end }}
{{- end }}

{{/*
Fill the ipFamily correctly
*/}}
{{- define "ipFamilyPolicy" -}}
{{- if .Values.service.ipFamilyPolicy }}
    {{- .Values.service.ipFamilyPolicy }}
{{ else }}
    {{- $dnsIPs := split "," .Values.global.clusterDNS }}
    {{- $dnsCount := len $dnsIPs }}
    {{- if gt $dnsCount 1 }}
        {{- "PreferDualStack" }}
    {{ else }}
        {{- "SingleStack" }}
    {{- end }}
{{- end }}
{{- end }}
    
