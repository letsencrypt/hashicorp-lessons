variable "say-hello-to" {
  type = string
}

variable "hello-world-sh-template" {
  type = string
}

job "hello-world" {
  datacenters = ["dev-general"]
  type        = "service"

  group "web" {
    count = 2

    network {

      port "web-listen" {}
    }

    task "server" {

      service {
        name = "hello-world"
        port = "web-listen"

        check {
          name     = "ready"
          type     = "tcp"
          port     = "web-listen"
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
        say-hello-to = "${var.say-hello-to}"
      }
    }
  }
}