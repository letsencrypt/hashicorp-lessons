// variable stanzas are used to declare variables that a job specification can
// have passed to it via `-var` and `-var-file` options on the nomad command
// line. https://www.nomadproject.io/docs/job-specification/hcl2/variables
variable "say-hello-to" {
  type = string
}

variable "hello-world-sh-template" {
  type = string
}

// job is the top-most configuration option in the job specification.
// https://www.nomadproject.io/docs/job-specification/job
job "hello-world" {

  // datacenters where you would like the hello-world to be deployed.
  // https://www.nomadproject.io/docs/job-specification/job#datacenters
  datacenters = ["dev-general"]

  // type of job that the hello world job is, since we want this app to be
  // supervised we select `service`.
  // https://www.nomadproject.io/docs/job-specification/job#type
  type = "service"

  // groups stanza defines a series of tasks that should be co-located on the
  // same Nomad worker. Any task within a group will be placed on the same
  // client. https://www.nomadproject.io/docs/job-specification/group
  group "web" {
    // count is the number of allocations (instances) of the hello-world app you
    // want to be deployed.
    // https://www.nomadproject.io/docs/job-specification/group#count
    count = 1

    // network stanza allows you to declare which ports need to be available on
    // a Nomad worker before it can allocate (deploy an instance of) the hello
    // world web server.
    // https://www.nomadproject.io/docs/job-specification/network
    network {
      // https://www.nomadproject.io/docs/job-specification/network#port-parameters
      port "web-listen" {
        static = 1234
      }
    }

    // task creates an individual unit of work for nomad the schedule and
    // supervise, for instance, a web server, or a database server.
    // https://www.nomadproject.io/docs/job-specification/task
    task "server" {
      // service tells the Nomad scheduler how it should register allocations of
      // the hello-world app should be advertised (as a service) in Consul and how
      // Consul should determine that the hello-world allocation is healthy enough
      // to advertise as part of the Service Catalog.
      // https://www.nomadproject.io/docs/job-specification/service
      service {
        name = "hello-world"
        port = "web-listen"
        // check is our health check for the hello world allocation. This one is
        // super simple; we only check that the "web-listen" tcp port is alive.
        // https://www.nomadproject.io/docs/job-specification/service#check
        check {
          name     = "server:tcp-alive"
          type     = "tcp"
          port     = "web-listen"
          interval = "3s"
          timeout  = "2s"
        }
      }
      // driver used to execute the task.
      // https://www.nomadproject.io/docs/job-specification/task#driver
      driver = "raw_exec"
      
      env {
        say-hello-to = "${var.say-hello-to}"
      }
      config {
        // command is the binary that sh will call.
        command = "${NOMAD_ALLOC_DIR}/hello-world.sh"
      }
      template {
        data        = var.hello-world-sh-template
        destination = "${NOMAD_ALLOC_DIR}/hello-world.sh"
        change_mode = "restart"
      }
    }
  }
}