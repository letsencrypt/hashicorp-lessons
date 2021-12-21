variable "hello-world-sh-template" {
  type = string
}

variable "traefik-config-template" {
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
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.http.rule=Path(`/`)",
        ]

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
    }
  }

  group "traefik" {
    count = 1

    network {
      port "http" {
        static = 8080
      }

      port "api" {
        static = 8081
      }
    }

    service {
      name = "traefik"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "raw_exec"

      config {
        command = "traefik"
        args = [
          "--configFile=${NOMAD_ALLOC_DIR}/traefik.toml",
        ]
      }

      template {
        data        = var.traefik-config-template
        destination = "${NOMAD_ALLOC_DIR}/traefik.toml"
      }
    }
  }
}
