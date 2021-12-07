// variable stanzas are used to declare variables that a job specification can
// have passed to it via `-var` and `-var-file` options on the nomad command
// line. https://www.nomadproject.io/docs/job-specification/hcl2/variables
variable "say-hello-to" {
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
      service "server" {
        name = "hello-world"
        port = "web-listen"

        // check is our health check for the hello world allocation. This one is
        // super simple; we only check that the "web-listen" tcp port is alive.
        // https://www.nomadproject.io/docs/job-specification/service#check
        check {
          name     = "attache:tcp-alive"
          type     = "tcp"
          port     = "web-listen"
          interval = "3s"
          timeout  = "2s"
        }
      }
      // driver used to execute the task.
      // https://www.nomadproject.io/docs/job-specification/task#driver
      driver = "exec"

      config {
        // command is the binary that sh will call.
        command = "socat"

        // args if you have them, will need to be added here. If you try to pass
        // them above, you will not have a fun time.
        //
        // below you can see that we're doing a little bit of variable
        // interpolation, you can read more on that here:
        // https://www.nomadproject.io/docs/runtime/interpolation
        //
        // one important bit to grok here though, is that if we want to use a
        // shell environment variable here, instead of interpolating a var we
        // declared in the job specification, we would need to escape this
        // variable with an extra "$" before the ${.
        args = [
          "-v",
          "-v",
          "TCP-LISTEN:1234,crlf,reuseaddr,fork SYSTEM:'echo",
          "HTTP/1.0 200;",
          "echo Content-Type:",
          "text/plain;",
          "echo;",
          "echo",
          "${var.say-hello-to}'"
        ]
      }
    }
  }
}