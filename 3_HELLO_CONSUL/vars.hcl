say-hello-to            = "Samantha"
hello-world-sh-template = <<-EOF
  #!/usr/bin/env bash
  {{ with $v := key "hello-world/config" | parseYAML }}
  socat -v -v TCP-LISTEN:{{ env "say-hello-port" }},crlf,reuseaddr,fork SYSTEM:'echo HTTP/1.0 200; echo Content-Type\: text/plain; echo; echo "Hello, {{ $v.to }}"'
  {{ end }}
EOF
