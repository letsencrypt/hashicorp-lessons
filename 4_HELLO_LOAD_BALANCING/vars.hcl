config-yml-template     = <<-EOF
  {{ with $v := key "hello-world/config" | parseYAML }}
  ---
  name: "{{ $v.name }}"
  port: {{ env "NOMAD_ALLOC_PORT_http" }}
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
