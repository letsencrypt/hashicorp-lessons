variable "say-hello-to" {
  type = string
}

variable "hello-world-sh-template" {
  type = string
}

job "hello-world" {
  datacenters = ["dev-general"]
  type        = "service"

  group "greeter" {
    count = 1

    network {

      port "http" {
        static = 1234
      }
    }

    service {
      name = "hello-world"
      port = "http"

      check {
        name     = "ready-tcp"
        type     = "tcp"
        port     = "http"
        interval = "3s"
        timeout  = "2s"
      }

      check {
        name     = "ready-http"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "3s"
        timeout  = "2s"
      }
    }

    task "server" {
      driver = "raw_exec"
      
      config {
        command = "${NOMAD_ALLOC_DIR}/hello-world.sh"
      }

      template {
        data        = var.hello-world-sh-template
        destination = "${NOMAD_ALLOC_DIR}/hello-world.sh"
        change_mode = "restart"
      }

      env {
        say-hello-to = "${var.say-hello-to}"
      }
    }
  }
}
