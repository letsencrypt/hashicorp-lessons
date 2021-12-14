# Hashicorp Lessons

## Install Nomad
https://learn.hashicorp.com/tutorials/nomad/get-started-install

## Install Consul
https://learn.hashicorp.com/tutorials/consul/get-started-install


## Getting Consul and Nomad started in dev mode

### Start the Consul server in `dev` mode:
```shell
$ consul agent -dev -datacenter dev-general -log-level ERROR
```

### Start the Nomad server in `dev` mode:
```shell
$ sudo nomad agent -dev -bind 0.0.0.0 -log-level ERROR -dc dev-general
```

1. Open the Nomad UI: http://localhost:4646/ui
1. Open the Consul UI: http://localhost:8500/ui

# (A Highly Commented) Nomad Job Specification

```hcl
// 'variable' stanzas are used to declare variables that a job specification can
// have passed to it via '-var' and '-var-file' options on the nomad command
// line. https://www.nomadproject.io/docs/job-specification/hcl2/variables
variable "say-hello-to" {
  type = string
}

variable "hello-world-sh-template" {
  type = string
}

// 'job' is the top-most configuration option in the job specification.
// https://www.nomadproject.io/docs/job-specification/job
job "hello-world" {

  // datacenters where you would like the hello-world to be deployed.
  // https://www.nomadproject.io/docs/job-specification/job#datacenters
  datacenters = ["dev-general"]

  // 'type' of Scheduler that Nomad will use to run and update the 'hello-world'
  // job. We're using 'service' in this example because we want the
  // 'hello-world' job to be run persistently and restarted if it becomes
  // unhealthy or stops unexpectedly.
  // https://www.nomadproject.io/docs/job-specification/job#type
  type = "service"

  // 'group' is a series of tasks that should be co-located (run) on the same
  // Nomad client. https://www.nomadproject.io/docs/job-specification/group
  group "web" {
    // 'count' is the number of allocations (instances) of the hello-world app
    // you want to be deployed.
    // https://www.nomadproject.io/docs/job-specification/group#count
    count = 1

    // 'network' declares which ports need to be available on a Nomad client
    // before it can allocate (deploy an instance of) the hello world web
    // server. https://www.nomadproject.io/docs/job-specification/network
    network {
      // https://www.nomadproject.io/docs/job-specification/network#port-parameters
      port "web-listen" {
        static = 1234
      }
    }

    // 'task' creates an individual unit of work for nomad the schedule and
    // supervise, for instance, a web server, or a database server.
    // https://www.nomadproject.io/docs/job-specification/task
    task "server" {

      // 'service' tells Nomad how the hello-world app should be advertised (as
      // a service) in Consul and how Consul should determine that the
      // hello-world allocation is healthy enough to advertise as part of the
      // Service Catalog.
      // https://www.nomadproject.io/docs/job-specification/service
      service {
        name = "hello-world"
        port = "web-listen"

        // 'check' is the check used by Consul to assess the health or readiness
        // of an indivual 'hello-world' allocation.
        // https://www.nomadproject.io/docs/job-specification/service#check
        check {
          name     = "ready"
          type     = "tcp"
          port     = "web-listen"
          interval = "3s"
          timeout  = "2s"
        }
      }
      // 'driver' is the Task Driver that Nomad should use to execute our
      // 'task'. For shell commands and scripts there are two options:
      // 1. 'raw_exec' is used to execute a command for a task without any
      //    isolation. The task is started as the same user as the Nomad
      //    process. Ensure the Nomad process user is sufficiently restricted in
      //    Production settings.
      // 2. 'exec' uses the underlying isolation primitives of the operating
      //    system to limit the task's access to resources
      // 3. There are many more here: https://www.nomadproject.io/docs/drivers
      //    https://www.nomadproject.io/docs/job-specification/task#driver 
      driver = "raw_exec"

      config {
        // 'command' is the binary or script that will be called with /bin/sh.
        command = "${NOMAD_ALLOC_DIR}/hello-world.sh"
        // If this command had any arguments you would pass them below using
        // arguments = [ "foo", "bar", "baz" ]
      }

      // 'template' instructs the Nomad Client to use 'consul-template' to
      // template a given file into the allocation at a specified path. Note:
      // that while 'consul-template' has 'consul' in the name, 'consul' is not
      // required to use it.
      // https://www.nomadproject.io/docs/job-specification/task#template
      // https://www.nomadproject.io/docs/job-specification/template
      template {
        // 'data' this can just be a string that you pass in as a var like
        // we've done here.
        data        = var.hello-world-sh-template
        destination = "${NOMAD_ALLOC_DIR}/hello-world.sh"
        change_mode = "restart"
      }

      // 'env' allows us to pass environment variables to our task. Since
      // consul-template is run locally inside of allocation we will need to
      // pass any Job Specification variables that we plan to use in our
      // template here.
      // https://www.nomadproject.io/docs/job-specification/task#env
      env {
        say-hello-to = "${var.say-hello-to}"
      }
    }
  }
}
```

# Workshop 1: Hello World
This less makes usees `socat`, a simple CLI based web server. Ensure that you've
got it installed before continuing.

## Run the `hello-world` Job:
```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
```

## Stop and purge the `hello-world` Job:
```shell
$ nomad job stop -purge "hello-world"
```
