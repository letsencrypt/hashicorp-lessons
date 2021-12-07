say-hello-to = "to  ...get it?"
hello-world-sh-template = <<-EOF
  #!/usr/bin/env bash
  socat -v -v TCP-LISTEN:1234,crlf,reuseaddr,fork SYSTEM:'echo HTTP/1.0 200; echo Content-Type\: text/plain; echo; echo {{ env "say-hello-to" }}'
EOF
