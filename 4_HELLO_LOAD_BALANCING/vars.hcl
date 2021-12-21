hello-world-sh-template = <<-EOF
  #!/usr/bin/env bash
  {{ with $v := key "hello-world/config" | parseYAML }}
  socat \
    -v \
    TCP-LISTEN:{{ env "NOMAD_ALLOC_PORT_http" }},crlf,reuseaddr,fork \
    SYSTEM:"
        echo HTTP/1.1 200 OK;
        echo Content-Type\: text/plain;
        echo;
        echo \"Hello, {{ $v.to }}!\";
    "
  {{ end }}
EOF
traefik-config-template = <<-EOF
  [entryPoints.http]
  address = ":{{ env "NOMAD_ALLOC_PORT_http" }}"
  
  [entryPoints.traefik]
  address = ":{{ env "NOMAD_ALLOC_PORT_dashboard" }}"
  
  [api]
  dashboard = true
  insecure = true
  
  [providers.consulCatalog]
  prefix = "hello-world-lb"
  exposedByDefault = false
  
  [providers.consulCatalog.endpoint]
  address = "{{ env "CONSUL_HTTP_ADDR" }}"
  scheme = "http"
EOF
