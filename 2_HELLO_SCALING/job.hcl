variable "config-yml-template" {
  type = string
}

job "hello-world" {
  datacenters = ["dev-general"]
  type        = "service"

  group "greeter" {
    count = 2

    network {
      port "http" {}
    }

    service {
      name = "hello-world-greeter"
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

    task "greet" {
      driver = "raw_exec"
      
      config {
        command = "greet"
        args = [
          "-c", "${NOMAD_ALLOC_DIR}/config.yml"
        ]
      }

      template {
        data        = var.config-yml-template
        destination = "${NOMAD_ALLOC_DIR}/config.yml"
        change_mode = "restart"
      }
    }
  }
}
