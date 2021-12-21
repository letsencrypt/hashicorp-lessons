hello-world-sh-template = <<-EOF
  #!/usr/bin/env bash
  {{ with $v := key "hello-world/config" | parseYAML }}
  socat \
    -v \
    TCP-LISTEN:{{ env "NOMAD_ALLOC_PORT_web-listen" }},crlf,reuseaddr,fork \
    SYSTEM:"
        echo HTTP/1.1 200 OK;
        echo Content-Type\: text/plain;
        echo;
        echo \"Hello, {{ $v.to }}!\";
    "
  {{ end }}
EOF
traefik-config-template = <<-EOF
  [entryPoints]
  [entryPoints.http]
  address = ":8080"
  
  [entryPoints.traefik]
  address = ":8081"
  
  [api]
  dashboard = true
  insecure = true
  
  [providers.consulCatalog]
  prefix = "traefik"
  exposedByDefault = false
  
  [providers.consulCatalog.endpoint]
  address = "127.0.0.1:8500"
  scheme = "http"
EOF
