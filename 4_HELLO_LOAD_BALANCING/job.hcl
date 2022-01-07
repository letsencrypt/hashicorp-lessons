variable "config-yml-template" {
  type = string
}

variable "traefik-config-template" {
  type = string
}

job "hello-world" {
  datacenters = ["dev-general"]
  type        = "service"

  group "load-balancer" {
    count = 1

    network {

      port "http" {
        static = 8080
      }

      port "dashboard" {
        static = 8081
      }
    }

    service {
      name = "hello-world-lb"
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

      check {
        name     = "ready-tcp"
        type     = "tcp"
        port     = "dashboard"
        interval = "3s"
        timeout  = "2s"
      }

      check {
        name     = "ready-http"
        type     = "http"
        port     = "dashboard"
        path     = "/"
        interval = "3s"
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
        change_mode = "restart"
      }
    }
  }

  group "greeter" {
    count = 2

    network {
      port "http" {}
    }


    service {
      name = "hello-world-greeter"
      port = "http"
      tags = [
        "hello-world-lb.enable=true",
        "hello-world-lb.http.routers.http.rule=Path(`/`)",
      ]

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
