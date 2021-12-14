hello-world-sh-template = <<-EOF
  #!/usr/bin/env bash
  socat -v -v TCP-LISTEN:{{ env "port" }},crlf,reuseaddr,fork SYSTEM:'echo HTTP/1.0 200; echo Content-Type\: text/plain; echo; echo "Hello, $(consul kv get hallo_welt/config) "'
EOF
