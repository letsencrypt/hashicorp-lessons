config-yml-template = <<-EOF
  ---
  name: "Samantha"
  port: {{ env "NOMAD_ALLOC_PORT_http" }}

EOF
