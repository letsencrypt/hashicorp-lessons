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

# Getting Started

## A Highly Commented Nomad Job Specification
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

## Workshop 1: Hello World
This less makes usees `socat` , a simple CLI based web server. Ensure that
you've got it installed before continuing.

### Check the plan output for the `hello-world` Job:
Running the `plan` subcommand will help us understand what actions the Nomad
Scheduler is going to take on our behalf. Now, you're proably seeing a whole lot
of changes here that were not included in our `hello-world` Job Specification.
This is because, in the absense of their explicit definition, Nomad will fill in
some defaults for required values.

```shell
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
+ Job: "hello-world"
+ AllAtOnce:  "false"
+ Dispatched: "false"
+ Name:       "hello-world"
+ Namespace:  "default"
+ Priority:   "50"
+ Region:     "global"
+ Stop:       "false"
+ Type:       "service"
+ Datacenters {
  + Datacenters: "dev-general"
  }
+ Task Group: "web" (1 create)
  + Count: "1" (forces create)
  + RestartPolicy {
    + Attempts: "2"
    + Delay:    "15000000000"
    + Interval: "1800000000000"
    + Mode:     "fail"
    }
  + ReschedulePolicy {
    + Attempts:      "0"
    + Delay:         "30000000000"
    + DelayFunction: "exponential"
    + Interval:      "0"
    + MaxDelay:      "3600000000000"
    + Unlimited:     "true"
    }
  + EphemeralDisk {
    + Migrate: "false"
    + SizeMB:  "300"
    + Sticky:  "false"
    }
  + Update {
    + AutoPromote:      "false"
    + AutoRevert:       "false"
    + Canary:           "0"
    + HealthCheck:      "checks"
    + HealthyDeadline:  "300000000000"
    + MaxParallel:      "1"
    + MinHealthyTime:   "10000000000"
    + ProgressDeadline: "600000000000"
    }
  + Network {
      Hostname: ""
    + MBits:    "0"
      Mode:     ""
    + Static Port {
      + HostNetwork: "default"
      + Label:       "web-listen"
      + To:          "0"
      + Value:       "1234"
      }
    }
  + Task: "server" (forces create)
    + Driver:            "raw_exec"
    + Env[say-hello-to]: "Samantha"
    + KillTimeout:       "5000000000"
    + Leader:            "false"
    + ShutdownDelay:     "0"
    + Config {
      + command: "${NOMAD_ALLOC_DIR}/hello-world.sh"
      }
    + Resources {
      + CPU:         "100"
      + Cores:       "0"
      + DiskMB:      "0"
      + IOPS:        "0"
      + MemoryMB:    "300"
      + MemoryMaxMB: "0"
      }
    + LogConfig {
      + MaxFileSizeMB: "10"
      + MaxFiles:      "10"
      }
    + Service {
      + AddressMode:       "auto"
      + EnableTagOverride: "false"
      + Name:              "hello-world"
      + Namespace:         "default"
      + OnUpdate:          "require_healthy"
      + PortLabel:         "web-listen"
        TaskName:          ""
      + Check {
          AddressMode:            ""
          Body:                   ""
          Command:                ""
        + Expose:                 "false"
        + FailuresBeforeCritical: "0"
          GRPCService:            ""
        + GRPCUseTLS:             "false"
          InitialStatus:          ""
        + Interval:               "3000000000"
          Method:                 ""
        + Name:                   "ready"
        + OnUpdate:               "require_healthy"
          Path:                   ""
        + PortLabel:              "web-listen"
          Protocol:               ""
        + SuccessBeforePassing:   "0"
        + TLSSkipVerify:          "false"
          TaskName:               ""
        + Timeout:                "2000000000"
        + Type:                   "tcp"
        }
      }
    + Template {
      + ChangeMode:   "restart"
        ChangeSignal: ""
      + DestPath:     "${NOMAD_ALLOC_DIR}/hello-world.sh"
      + EmbeddedTmpl: "#!/usr/bin/env bash\nsocat \\\n  -v \\\n  TCP-LISTEN:1234,crlf,reuseaddr,fork \\\n  SYSTEM:\"\n      echo HTTP/1.1 200 OK;\n      echo Content-Type\\: text/plain;\n      echo;\n      echo \\\"Hello, {{ env \"say-hello-to\" }}!\\\";\n  \"\n"
      + Envvars:      "false"
      + LeftDelim:    "{{"
      + Perms:        "0644"
      + RightDelim:   "}}"
        SourcePath:   ""
      + Splay:        "5000000000"
      + VaultGrace:   "0"
      }

Scheduler dry-run:
- All tasks successfully allocated.
```

### Run the `hello-world` Job:
We expect that running our `hello-world` job should succeed just because the
`plan` output above stated that all of our tasks would be successfully
allocated. Let's find out!

```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
```

### Load up the the `hello-world` URL in your browser:
http://localhost:1234

You should see:
```
Hello, Samantha!
```

### Let's make that say _YOUR NAME_ instead of _Samantha_:
Edit line `1` in `1_HELLO_WORLD/vars.hcl` to be YOUR NAME:

```hcl
say-hello-to = "YOUR NAME"
```

### Check the plan output for the `hello-world` Job:
```shell
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
+/- Job: "hello-world"
+/- Task Group: "web" (1 create/destroy update)
  +/- Task: "server" (forces create/destroy update)
    +/- Env[say-hello-to]: "Samantha" => "YOUR NAME"

Scheduler dry-run:
- All tasks successfully allocated.
```

Looks like it's going to work out just fine!

### Let's go ahead and deploy our updated `hello-world` Job:
```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
```

### Load up the the `hello-world` URL in your browser
If you go to: http://localhost:1234, you should now see:

```
Hello, YOUR NAME!
```

## Workshop 2: Hello Scaling
It's time to scale our `hello-world` job. It's best if you follow the
documentation here to update your Job specification at `1_HELLO_WORLD/job.hcl`

and your vars file at `1_HELLO_WORLD/vars.hcl` , but if you get lost you can see
the final product under `2_HELLO_SCALING/job.hcl` and `2_HELLO_SCALING/vars.hcl`
.

### Okay, let's try incrementing the count in our Job Specification:
Edit `job >> group "web" >> count` in `1_HELLO_WORLD/job.hcl` from `1` to `2` :

```hcl
    count = 2
```

### Check the plan output for the `hello-world` Job:
```shell
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
+/- Job: "hello-world"
+/- Task Group: "web" (1 create, 1 in-place update)
  +/- Count: "1" => "2" (forces create)
      Task: "server"

Scheduler dry-run:
- WARNING: Failed to place all allocations.
  Task Group "web" (failed to place 1 allocation):
    * Resources exhausted on 1 nodes
    * Dimension "network: reserved port collision web-listen=1234" exhausted on 1 nodes
```

It looks like having a static port of `1234` is going to cause resource
exhaustion. Not to worry though, we can update our Job Specification to let the
Nomad Scheduler pick a port for each of our `hello-world` allocations to listen
on.

### Update our `hello-world` Job Specification to make port selection dynamic
Under `job >> group "web" >> network >> port` we can remove our static port
assignment of `1234` and leave empty curly braces `{}` . This will instruct the
Nomad Scheduler dynamically assign the port for each allocation.

Our existing lines:

```shell
      port "web-listen" {
        static = 1234
      }
```

Our new line:

```shell
      port "web-listen" {}
```

### Update our `socat` script template to template our dynamic port
We expect the environment variable to be `NOMAD_ALLOC_PORT_web-listen` because
the network port we declared on under `job >> group "web" >> network >> port` is
called `web-listen` . If we had called it `my-special-port` we would use
`NOMAD_ALLOC_PORT_my-special-port`

By replacing `1234` in our `socat` script template the
`NOMAD_ALLOC_PORT_web-listen` environment variable our template will always stay
up-to-date.

Our existing line:
```shell
    TCP-LISTEN:1234,crlf,reuseaddr,fork \
```

Our new line:
```shell
    TCP-LISTEN:{{ env "NOMAD_ALLOC_PORT_web-listen" }},crlf,reuseaddr,fork \
```

For more info on Nomad Runtime Environment Variables
https://www.nomadproject.io/docs/runtime/environment

### Check the plan output of updated `hello-world` Job:
```shell
+/- Job: "hello-world"
+/- Task Group: "web" (1 create, 1 ignore)
  +/- Count: "1" => "2" (forces create)
  +   Network {
        Hostname: ""
      + MBits:    "0"
        Mode:     ""
      + Dynamic Port {
        + HostNetwork: "default"
        + Label:       "web-listen"
        + To:          "0"
        }
      }
  -   Network {
        Hostname: ""
      - MBits:    "0"
        Mode:     ""
      - Static Port {
        - HostNetwork: "default"
        - Label:       "web-listen"
        - To:          "0"
        - Value:       "1234"
        }
      }
  +/- Task: "server" (forces create/destroy update)
    +/- Template {
          ChangeMode:   "restart"
          ChangeSignal: ""
          DestPath:     "${NOMAD_ALLOC_DIR}/hello-world.sh"
      +/- EmbeddedTmpl: "#!/usr/bin/env bash\nsocat \\\n  -v \\\n  TCP-LISTEN:1234,crlf,reuseaddr,fork \\\n  SYSTEM:\"\n      echo HTTP/1.1 200 OK;\n      echo Content-Type\\: text/plain;\n      echo;\n      echo \\\"Hello, {{ env \"say-hello-to\" }}!\\\";\n  \"\n" => "#!/usr/bin/env bash\nsocat \\\n  -v \\\n  TCP-LISTEN:{{ env \"NOMAD_ALLOC_PORT_web-listen\" }},crlf,reuseaddr,fork \\\n  SYSTEM:\"\n      echo HTTP/1.1 200 OK;\n      echo Content-Type\\: text/plain;\n      echo;\n      echo \\\"Hello, {{ env \"say-hello-to\" }}!\\\";\n  \"\n"
          Envvars:      "false"
          LeftDelim:    "{{"
          Perms:        "0644"
          RightDelim:   "}}"
          SourcePath:   ""
          Splay:        "5000000000"
          VaultGrace:   "0"
        }

Scheduler dry-run:
- All tasks successfully allocated.
```

Okay, this looks as though it will work!

### Run the updated `hello-world` Job:
```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
```

### Let's fetch our the ports of our 2 new `hello-world` allocations
There are four ways that we can fetch the ports that Nomad assigned to our
`hello-world` allocations:

The first is via the Nomad web UI:
* Open: http://localhost:4646/ui/jobs/hello-world/web
* Scroll down to the `Allocations` table
* Open each of the `Allocations` where Status is `running`
* Scroll down to the `Ports` table, and note the value for `web-listen` in the
  `Host Address` column

The Nomad web UI is super nice, but some of us would rather use a CLI:

* Run `nomad job status hello-world` and note the `ID` for each `Allocation`
  with `running` in the `Status` column:
  ```shell
  $ nomad job status hello-world
  ID            = hello-world
  Name          = hello-world
  Submit Date   = 2021-12-15T12:23:47-08:00
  Type          = service
  Priority      = 50
  Datacenters   = dev-general
  Namespace     = default
  Status        = running
  Periodic      = false
  Parameterized = false

  Summary
  Task Group  Queued  Starting  Running  Failed  Complete  Lost
  web         0       0         2        0       1         0

  Latest Deployment
  ID          = 2b1569b6
  Status      = successful
  Description = Deployment completed successfully

  Deployed
  Task Group  Desired  Placed  Healthy  Unhealthy  Progress Deadline
  web         2        2       2        0          2021-12-15T12:34:18-08:00

  Allocations
  ID        Node ID   Task Group  Version  Desired  Status    Created    Modified
  ae931625  65849030  web         1        run      running   5m41s ago  5m25s ago
  5b561feb  65849030  web         1        run      running   5m55s ago  5m43s ago
  f7a7d503  65849030  web         0        stop     complete  7m29s ago  5m36s ago
  ```
* Run `nomad alloc status <allocation-id>` for each `ID`:
  ```shell
  $ nomad alloc status ae931625
  ID                  = ae931625-0f89-0d07-354e-e5cd414489c4
  Eval ID             = 7f52e032
  Name                = hello-world.web[0]
  Node ID             = 65849030
  Node Name           = treepie.local
  Job ID              = hello-world
  Job Version         = 1
  Client Status       = running
  Client Description  = Tasks are running
  Desired Status      = run
  Desired Description = <none>
  Created             = 12m35s ago
  Modified            = 12m19s ago
  Deployment ID       = 2b1569b6
  Deployment Health   = healthy

  Allocation Addresses
  Label        Dynamic  Address
  *web-listen  yes      127.0.0.1:24701

  Task "server" is "running"
  Task Resources
  CPU        Memory          Disk     Addresses
  0/100 MHz  48 MiB/300 MiB  300 MiB

  Task Events:
  Started At     = 2021-12-15T20:24:06Z
  Finished At    = N/A
  Total Restarts = 0
  Last Restart   = N/A

  Recent Events:
  Time                       Type        Description
  2021-12-15T12:24:06-08:00  Started     Task started by client
  2021-12-15T12:24:06-08:00  Task Setup  Building Task Directory
  2021-12-15T12:24:01-08:00  Received    Task received by client
  ```
* Under `Allocation Addresses` we can see `127.0.0.1:24701` is the address for
  this Allocation

In our `hello-world` Job Specification you'll see that we also registered our
`server` task with the Consul Catalog as a Service called `hello-world`. This
means that we can also grab these addresses and ports via the Consul Web UI:
* Open http://localhost:8500/ui/dev-general/services/hello-world/instances
* On the right-hand side of each entry you can find the complete IP address and
  port for each of our `hello-world` allocations.

But, how would a service be able to locate these `hello-world` allocations? Well
sure, you could install embed a Consul Client in some of your other services
that want to connect with `hello-world`, but there's something a little simpler
that you can do as a first approach, use the DNS endpoint that Consul exposes by
default to fetch theses addresses and ports in the form of a SRV record.
```
$ dig @127.0.0.1 -p 8600 hello-world.service.dev-general.consul. SRV

; <<>> DiG 9.10.6 <<>> @127.0.0.1 -p 8600 hello-world.service.dev-general.consul. SRV
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 61812
;; flags: qr aa rd; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 5
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;hello-world.service.dev-general.consul.  IN SRV

;; ANSWER SECTION:
hello-world.service.dev-general.consul. 0 IN SRV 1 1 27047 7f000001.addr.dev-general.consul.
hello-world.service.dev-general.consul. 0 IN SRV 1 1 24701 7f000001.addr.dev-general.consul.

;; ADDITIONAL SECTION:
7f000001.addr.dev-general.consul. 0 IN  A 127.0.0.1
treepie.local.node.dev-general.consul. 0 IN TXT "consul-network-segment="
7f000001.addr.dev-general.consul. 0 IN  A 127.0.0.1
treepie.local.node.dev-general.consul. 0 IN TXT "consul-network-segment="

;; Query time: 0 msec
;; SERVER: 127.0.0.1#8600(127.0.0.1)
;; WHEN: Wed Dec 15 12:47:15 PST 2021
;; MSG SIZE  rcvd: 294
```

## Workshop 3: Hello Consul
Coming Soon
