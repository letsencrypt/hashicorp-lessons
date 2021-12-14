variable "hello-world-sh-template" {
  type = string
}

job "hello-world" {
  datacenters = ["dev-general"]
  type        = "service"

  group "web" {
    count = 2

    network {
      port "web-exploit" {}
    }

    task "server" {

      service {
        name = "hello-world"
        port = "web-exploit"

        check {
          name     = "server:tcp-alive"
          type     = "tcp"
          port     = "web-exploit"
          interval = "3s"
          timeout  = "2s"
        }
      }
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
        port = "${NOMAD_ALLOC_PORT_web-exploit}"
      }
    }
  }
}
