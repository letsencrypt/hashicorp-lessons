config-yml-template = <<-EOF
  {{ with $v := key "hello-world/config" | parseYAML }}
  ---
  name: "{{ $v.name }}"
  port: {{ env "NOMAD_ALLOC_PORT_http" }}
  {{ end }}
  
EOF
