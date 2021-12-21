say-hello-to            = "Samantha"
hello-world-sh-template = <<-EOF
  #!/usr/bin/env bash
  socat \
    -v \
    TCP-LISTEN:{{ env "NOMAD_ALLOC_PORT_http" }},crlf,reuseaddr,fork \
    SYSTEM:"
        echo HTTP/1.1 200 OK;
        echo Content-Type\: text/plain;
        echo;
        echo \"Hello, {{ env "say-hello-to" }}!\";
    "
EOF
