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
  group "greeter" {
    // 'count' is the number of allocations (instances) of the hello-world app
    // you want to be deployed.
    // https://www.nomadproject.io/docs/job-specification/group#count
    count = 1

    // 'network' declares which ports need to be available on a Nomad client
    // before it can allocate (deploy an instance of) the hello world web
    // server. https://www.nomadproject.io/docs/job-specification/network
    network {
      // https://www.nomadproject.io/docs/job-specification/network#port-parameters
      port "http" {
        static = 1234
      }
    }

    // 'service' tells Nomad how the hello-world app should be advertised (as a
    // service) in Consul and how Consul should determine that the hello-world
    // allocation is healthy enough to advertise as part of the Service Catalog.
    // https://www.nomadproject.io/docs/job-specification/service
    service {
      name = "hello-world"
      port = "http"

      // 'check' is the check used by Consul to assess the health or readiness
      // of an indivual 'hello-world' allocation.
      // https://www.nomadproject.io/docs/job-specification/service#check
      check {
        name     = "ready-tcp"
        type     = "tcp"
        port     = "http"
        interval = "3s"
        timeout  = "2s"
      }

      // 'check' same as the above except the status of the service depends on the HTTP
      // response code: any 2xx code is considered passing, a 429 Too ManyRequests is
      // warning, and anything else is a failure.
      check {
        name     = "ready-http"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "3s"
        timeout  = "2s"
      }
    }

    // 'task' creates an individual unit of work for nomad the schedule and
    // supervise, for instance, a web server, or a database server.
    // https://www.nomadproject.io/docs/job-specification/task
    task "server" {
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
        // 'data' this can just be a string that you pass in as a var like we've
        // done here.
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
This less makes use of `socat`, a simple CLI based web server. Ensure that
you've got it installed before continuing.

## Check the plan output for the `hello-world` Job
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
+ Task Group: "greeter" (1 create)
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
      + Label:       "http"
      + To:          "0"
      + Value:       "1234"
      }
    }
  + Service {
    + AddressMode:       "auto"
    + EnableTagOverride: "false"
    + Name:              "hello-world"
    + Namespace:         "default"
    + OnUpdate:          "require_healthy"
    + PortLabel:         "http"
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
      + Name:                   "ready-http"
      + OnUpdate:               "require_healthy"
      + Path:                   "/"
      + PortLabel:              "http"
        Protocol:               ""
      + SuccessBeforePassing:   "0"
      + TLSSkipVerify:          "false"
        TaskName:               ""
      + Timeout:                "2000000000"
      + Type:                   "http"
      }
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
      + Name:                   "ready-tcp"
      + OnUpdate:               "require_healthy"
        Path:                   ""
      + PortLabel:              "http"
        Protocol:               ""
      + SuccessBeforePassing:   "0"
      + TLSSkipVerify:          "false"
        TaskName:               ""
      + Timeout:                "2000000000"
      + Type:                   "tcp"
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

## Run the `hello-world` Job
We expect that running our `hello-world` job should succeed because the `plan`
output above stated that all of our tasks would be successfully allocated. Let's
find out!

```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
```

## Load up the the `hello-world` URL in your browser:
http://localhost:1234

You should see:
```
Hello, Samantha!
```

## Let's make that say _YOUR NAME_ instead of _Samantha_:
Edit line `1` in `1_HELLO_WORLD/vars.hcl` to be YOUR NAME:

```hcl
say-hello-to = "YOUR NAME"
```

## Check the plan output for the `hello-world` Job
```shell
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
+/- Job: "hello-world"
+/- Task Group: "greeter" (1 create/destroy update)
  +/- Task: "server" (forces create/destroy update)
    +/- Env[say-hello-to]: "Samantha" => "YOUR NAME"

Scheduler dry-run:
- All tasks successfully allocated.
```

Looks like it's going to work out just fine!

## Let's go ahead and deploy our updated `hello-world` Job
```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
```

## Load up the the `hello-world` URL in your browser
If you go to: http://localhost:1234, you should now see:

```
Hello, YOUR NAME!
```

# Workshop 2: Hello Scaling
It's time to scale our `hello-world` job. It's best if you follow the
documentation here to update your Job specification at `1_HELLO_WORLD/job.hcl`
and your vars file at `1_HELLO_WORLD/vars.hcl`, but if you get lost you can see
the final product under `2_HELLO_SCALING/job.hcl` and
`2_HELLO_SCALING/vars.hcl`.

## Let's try incrementing the count in our Job Specification:
Edit `job >> group "greeter" >> count` in `1_HELLO_WORLD/job.hcl` from `1` to
`2`:

```hcl
    count = 2
```

## Check the plan output for the `hello-world` Job
```shell
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
+/- Job: "hello-world"
+/- Task Group: "greeter" (1 create, 1 in-place update)
  +/- Count: "1" => "2" (forces create)
      Task: "server"

Scheduler dry-run:
- WARNING: Failed to place all allocations.
  Task Group "greeter" (failed to place 1 allocation):
    * Resources exhausted on 1 nodes
    * Dimension "network: reserved port collision http=1234" exhausted on 1 nodes
```

It looks like having a static port of `1234` is going to cause resource
exhaustion. Not to worry though, we can update our Job Specification to let the
Nomad Scheduler pick a port for each of our `hello-world` allocations to listen
on.

## Update our `hello-world` Job Specification to make port selection dynamic
Under `job >> group "greeter" >> network >> port` we can remove our static port
assignment of `1234` and leave empty curly braces `{}` . This will instruct the
Nomad Scheduler dynamically assign the port for each allocation.

Our existing lines:

```shell
      port "http" {
        static = 1234
      }
```

Our new line:

```shell
      port "http" {}
```

## Update our `socat` script template to use our dynamic port
By replacing `1234` in our `socat` script template the `NOMAD_ALLOC_PORT_http`
environment variable our template will always stay up-to-date.

We expect the environment variable to be `NOMAD_ALLOC_PORT_http` because the
network port we declare at `job >> group "greeter" >> network >> port` is called
`http` . If we had called it `my-special-port` we would use
`NOMAD_ALLOC_PORT_my-special-port`.

Our existing line:
```shell
    TCP-LISTEN:1234,crlf,reuseaddr,fork \
```

Our new line:
```shell
    TCP-LISTEN:{{ env "NOMAD_ALLOC_PORT_http" }},crlf,reuseaddr,fork \
```

For more info on Nomad Runtime Environment Variables see these
[docs](https://www.nomadproject.io/docs/runtime/environment).

## Check the plan output of updated `hello-world` Job
```shell
+/- Job: "hello-world"
+/- Task Group: "greeter" (1 create, 1 ignore)
  +/- Count: "1" => "2" (forces create)
  +   Network {
        Hostname: ""
      + MBits:    "0"
        Mode:     ""
      + Dynamic Port {
        + HostNetwork: "default"
        + Label:       "http"
        + To:          "0"
        }
      }
  -   Network {
        Hostname: ""
      - MBits:    "0"
        Mode:     ""
      - Static Port {
        - HostNetwork: "default"
        - Label:       "http"
        - To:          "0"
        - Value:       "1234"
        }
      }
  +/- Task: "server" (forces create/destroy update)
    +/- Template {
          ChangeMode:   "restart"
          ChangeSignal: ""
          DestPath:     "${NOMAD_ALLOC_DIR}/hello-world.sh"
      +/- EmbeddedTmpl: "#!/usr/bin/env bash\nsocat \\\n  -v \\\n  TCP-LISTEN:1234,crlf,reuseaddr,fork \\\n  SYSTEM:\"\n      echo HTTP/1.1 200 OK;\n      echo Content-Type\\: text/plain;\n      echo;\n      echo \\\"Hello, {{ env \"say-hello-to\" }}!\\\";\n  \"\n" => "#!/usr/bin/env bash\nsocat \\\n  -v \\\n  TCP-LISTEN:{{ env \"NOMAD_ALLOC_PORT_http\" }},crlf,reuseaddr,fork \\\n  SYSTEM:\"\n      echo HTTP/1.1 200 OK;\n      echo Content-Type\\: text/plain;\n      echo;\n      echo \\\"Hello, {{ env \"say-hello-to\" }}!\\\";\n  \"\n"
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

## Run the updated `hello-world` Job
```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
```

## Let's fetch our the ports of our 2 new `hello-world` allocations
There are a few ways that we can fetch the ports that Nomad assigned to our
`hello-world` allocations:

The first is via the Nomad web UI:
* Open: http://localhost:4646/ui/jobs/hello-world/web
* Scroll down to the `Allocations` table
* Open each of the `Allocations` where Status is `running`
* Scroll down to the `Ports` table, and note the value for `http` in the `Host
  Address` column

The Nomad web UI is super nice, but some of us would rather use a CLI:

* Run `nomad job status hello-world` and note the `ID` for each allocation with
  `running` in the `Status` column:
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
  *http  yes      127.0.0.1:24701

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
  this allocation

In our `hello-world` Job Specification you'll see that we also registered our
`server` task with the Consul Catalog as a Service called `hello-world`. This
means that we can also grab these addresses and ports via the Consul Web UI:
* Open http://localhost:8500/ui/dev-general/services/hello-world/instances
* On the right-hand side of each entry you can find the complete IP address and
  port for each of our `hello-world` allocations.

But, how would a service be able to locate these `hello-world` allocations? Well
sure, you could integrate a Consul Client into these other services that want to
connect with `hello-world`, but there's something a little simpler that you can
do as a first approach, use the DNS endpoint that Consul exposes by default to
fetch theses addresses and ports in the form of a SRV record.
```shell
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

Given the output of this `SRV` record you should be able to browse to
http://localhost:27047 or http://localhost:24701 and be greeted.

If you follow [these
docs](https://learn.hashicorp.com/tutorials/consul/dns-forwarding) you should
also be able to browse to http://hello-world.service.dev-general.consul:27047 or
http://hello-world.service.dev-general.consul:24701.

# Workshop 3: Hello Consul
It's best if you follow the documentation here to update your Job specification
at `1_HELLO_WORLD/job.hcl` and your vars file at `1_HELLO_WORLD/vars.hcl`, but
if you get lost you can see the final product under `3_HELLO_CONSUL/job.hcl` and
`3_HELLO_CONSUL/vars.hcl`.

Redploying `hello-world` every time we want to change the name we're saying
hello to seems a little heavy handed when we really just need to update our
`socat` template and restart our `server` task. So, how can we accomplish this
without a deploy? One option is storing this name in Consul.

Nomad ships with a tool called `consul-template` that we've actually already
been using this entire time. Our `template` stanza in the `server` task uses
`consul-template` to template our `socat` shell script.

```hcl
      template {
        data        = var.hello-world-sh-template
        destination = "${NOMAD_ALLOC_DIR}/hello-world.sh"
        change_mode = "restart"
      }
```

We can instruct `consul-template` to retrieve the name of the person we're
saying hello to from the Consul K/V store while deploying our `hello-world`
allocations. After an initial deploy, Nomad will then watch the Consul K/V path
for changes to the name. If a change is detected, Nomad will re-run
`consul-template` with the updated value and then take the action specified by
the `change_mode` attribute of our `template` stanza. In our case, it will
`restart` the `server` task.

## Modify our `socat` script template to source from Consul
Our template var in `1_HELLO_WORLD/vars.hcl` is currently:
```hcl
hello-world-sh-template = <<-EOF
  #!/usr/bin/env bash
  socat \
    -v \
    TCP-LISTEN:{{ env "NOMAD_ALLOC_PORT_http" }},crlf,reuseaddr,fork \
    SYSTEM:"
        echo HTTP/1.1 200 OK;
        echo Content-Type\: text/plain;
        echo;
        echo \"Hello, {{ env "say-hello-to" }}!\";
    "
EOF

```

We should edit it like so:
```hcl
hello-world-sh-template = <<-EOF
  #!/usr/bin/env bash
  {{ with $v := key "hello-world/config" | parseYAML }}
  socat \
    -v \
    TCP-LISTEN:{{ env "NOMAD_ALLOC_PORT_http" }},crlf,reuseaddr,fork \
    SYSTEM:"
        echo HTTP/1.1 200 OK;
        echo Content-Type\: text/plain;
        echo;
        echo \"Hello, {{ $v.to }}!\";
    "
  {{ end }}
EOF

```
Here we're setting a variable `v` with the parsed contents of the YAML stored at
the Consul K/V path of `hello-world/config`. We're then templating the value of
the `to` key.

Note: make sure you leave an empty newline at the end of your vars file
otherwise the Nomad CLI won't be able to parse it properly.

## Push our YAML formatted config to Consul
We could do this with the Consul web UI but using the `consul` CLI is much
faster.

```shell
$ consul kv put 'hello-world/config' 'to: Samantha'
Success! Data written to: hello-world/config

$ consul kv get 'hello-world/config'
to: "Samantha"
```

Here we've pushed a `to` key with a value of `"Samantha"` to the
`hello-world/config` Consul K/V. We have also fetched it just to be sure.

## Remove `say-hello-to` from our vars
Since we're storing this name in Consul we won't need `say-hello-to` in our vars
file, we should remove this line:

```hcl
say-hello-to            = "Samantha"
```

We can safely remove this variable declaration from our Job Specification as
well.

```hcl
variable "say-hello-to" {
  type = string
}
```

And lastly, we've been passing `var.say-hello-to` as an environment variable for
use in our `socat` template. We can now remove this line, and the `env` stanza
below, entirely:

```hcl
      env {
        say-hello-to = "${var.say-hello-to}"
      }
```

## Check the plan output for our updated `hello-world` Job
```shell
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
+/- Job: "hello-world"
+/- Task Group: "greeter" (1 create/destroy update, 1 ignore)
  +/- Task: "server" (forces create/destroy update)
    -   Env[say-hello-to]: "Samantha"
    +/- Template {
          ChangeMode:   "restart"
          ChangeSignal: ""
          DestPath:     "${NOMAD_ALLOC_DIR}/hello-world.sh"
      +/- EmbeddedTmpl: "#!/usr/bin/env bash\nsocat \\\n  -v \\\n  TCP-LISTEN:{{ env \"NOMAD_ALLOC_PORT_http\" }},crlf,reuseaddr,fork \\\n  SYSTEM:\"\n      echo HTTP/1.1 200 OK;\n      echo Content-Type\\: text/plain;\n      echo;\n      echo \\\"Hello, {{ env \"say-hello-to\" }}!\\\";\n  \"\n" => "#!/usr/bin/env bash\n{{ with $v := key \"hello-world/config\" | parseYAML }}\nsocat \\\n  -v \\\n  TCP-LISTEN:{{ env \"NOMAD_ALLOC_PORT_http\" }},crlf,reuseaddr,fork \\\n  SYSTEM:\"\n      echo HTTP/1.1 200 OK;\n      echo Content-Type\\: text/plain;\n      echo;\n      echo \\\"Hello, {{ $v.to }}!\\\";\n  \"\n{{ end }}\n"
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

Alright this looks like it should work.

## Run our updated `hello-world` Job
```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
```

## Get our new ports
```shell
$ dig @127.0.0.1 -p 8600 hello-world.service.dev-general.consul. SRV | grep hello-world.service
; <<>> DiG 9.10.6 <<>> @127.0.0.1 -p 8600 hello-world.service.dev-general.consul. SRV
;hello-world.service.dev-general.consul.  IN SRV
hello-world.service.dev-general.consul. 0 IN SRV 1 1 24360 7f000001.addr.dev-general.consul.
hello-world.service.dev-general.consul. 0 IN SRV 1 1 31370 7f000001.addr.dev-general.consul.
```

You should be able to browse to http://localhost:24360 or http://localhost:31370
and be greeted.

## Update the value of `to` in Consul
```shell
$ consul kv put 'hello-world/config' 'to: SAMANTHA'
Success! Data written to: hello-world/config

$ consul kv get 'hello-world/config'
to: "SAMANTHA"
```

## Browse to our `hello-world` allocations again
If you reload http://localhost:24360 or http://localhost:31370 you should be
greeted by your updated name. This did not require a deployment; Nomad was
notified that the value at the Consul K/V path of `hello-world/config` had been
updated. Nomad re-templated our `socat` shell script and then restarted our
`server` task just like we asked (in the `template` stanza).

Note: you may have observed a downtime of about 5 seconds between when the
`server` task being stopped and when it was started again. This is the default
wait time between stop and start operations and it's entirely configurable on a
per Job basis.

# Workshop 4: Hello Load Balancing
In this workshop we're going to be using Traefik, an open-source edge-router
written in Go with fantastic Consul integration. Please ensure that you've got
version 2.5.x installed and in your path.

I was able to fetch the binary via Homebrew on MacOS but you can always fetch
the latest binary for your platform from their
[releases](https://github.com/traefik/traefik/releases) page.

## Add a Traefik config template to our vars file
Out Traefik config is a minimal `.toml` file. Our first two declarations are
HTTP `entryPoints`. This is similar to `http { server {` in NGINX parlance. The
only attribute we need need to template is the `<hostname>:<port>`. The first is
the `greeter` load-balancer and the second is the Traefik dashboard (not
required). For both of these we can rely on the Nomad environment variables for
two new ports we're going to add to our job specification `http` and
`dashboard`. Again, we prefix these with `NOMAD_ALLOC_PORT_` and Nomad will do
the rest for us.

The next declaration is `api`. Here we're just going to enable the `dashboard`
and disable `tls`.

The final declarations enable and configure the `consulCatalog` provider. There
are two attributes in the first declaration. `prefix` configures the provider to
exclusively query for Consul catalog hosts tagged with `prefix:hello-world-lb`.
`exposedByDefault` (false) configures the provider to query only Consul services
tagged with `traefik.enable=true`. The last declaration instructs the provider
on how to connect to Consul. Because Nomad and Consul are already tightly
integrated we can template `address` with the `CONSUL_HTTP_ADDR` env var. As for
`scheme`, since we're using Consul in `dev` mode this is `http`.

```hcl
traefik-config-template = <<-EOF
  [entryPoints.http]
  address = ":{{ env "NOMAD_ALLOC_PORT_http" }}"
  
  [entryPoints.traefik]
  address = ":{{ env "NOMAD_ALLOC_PORT_dashboard" }}"
  
  [api]
  dashboard = true
  insecure = true
  
  [providers.consulCatalog]
  prefix = "hello-world-lb"
  exposedByDefault = false
  
  [providers.consulCatalog.endpoint]
  address = "{{ env "CONSUL_HTTP_ADDR" }}"
  scheme = "http"
EOF

```

Ensure that you add a newline at the end of this file otherwise Nomad will be
unable to parse it.

## Declare our new `traefik-config-template` varable in the job specification
Near the top, just below our existing `hello-world-sh-template` variable
declaration add the following:

```hcl
variable "traefik-config-template" {
  type = string
}
```

## Add a new `group` called `load-balancer` above our existing `greeter`
Our Traefik load-balancer will route requests on port `8080` to any healthy
`greeter` allocation. Traefik will also expose a dashboard on port `8081`. We've
added static ports for both the load-balancer (`http`) and the dashboard under
the `network` stanza. We've also added some TCP and HTTP readiness checks that
reference these ports in our new `hello-world-lb` Consul service.

```hcl
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
```

## Lastly, add some tags to the `hello-world` service
Under the `greeter` group you should see the `service` stanza. Adjust yours to
include the tags from the Traefik config.

```hcl
    service {
      name = "hello-world"
      port = "http"
      tags = [
        "hello-world-lb.enable=true",
        "hello-world-lb.http.routers.http.rule=Path(`/`)",
      ]
```


## Check the plan output for our updated `hello-world` Job
```shell
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
+/- Job: "hello-world"
+/- Task Group: "greeter" (2 in-place update)
  +/- Service {
      AddressMode:       "auto"
      EnableTagOverride: "false"
      Name:              "hello-world"
      Namespace:         "default"
      OnUpdate:          "require_healthy"
      PortLabel:         "http"
      TaskName:          ""
    + Tags {
      + Tags: "hello-world-lb.enable=true"
      + Tags: "hello-world-lb.http.routers.http.rule=Path(`/`)"
      }
      }
      Task: "server"

+   Task Group: "load-balancer" (1 create)
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
        + Label:       "http"
        + To:          "0"
        + Value:       "8080"
        }
      + Static Port {
        + HostNetwork: "default"
        + Label:       "dashboard"
        + To:          "0"
        + Value:       "8081"
        }
      }
    + Service {
      + AddressMode:       "auto"
      + EnableTagOverride: "false"
      + Name:              "hello-world-lb"
      + Namespace:         "default"
      + OnUpdate:          "require_healthy"
      + PortLabel:         "http"
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
        + Name:                   "ready-http"
        + OnUpdate:               "require_healthy"
        + Path:                   "/"
        + PortLabel:              "dashboard"
          Protocol:               ""
        + SuccessBeforePassing:   "0"
        + TLSSkipVerify:          "false"
          TaskName:               ""
        + Timeout:                "2000000000"
        + Type:                   "http"
        }
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
        + Name:                   "ready-tcp"
        + OnUpdate:               "require_healthy"
          Path:                   ""
        + PortLabel:              "dashboard"
          Protocol:               ""
        + SuccessBeforePassing:   "0"
        + TLSSkipVerify:          "false"
          TaskName:               ""
        + Timeout:                "2000000000"
        + Type:                   "tcp"
        }
      }
    + Task: "traefik" (forces create)
      + Driver:        "raw_exec"
      + KillTimeout:   "5000000000"
      + Leader:        "false"
      + ShutdownDelay: "0"
      + Config {
        + args[0]: "--configFile=${NOMAD_ALLOC_DIR}/traefik.toml"
        + command: "traefik"
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
      + Template {
        + ChangeMode:   "restart"
          ChangeSignal: ""
        + DestPath:     "${NOMAD_ALLOC_DIR}/traefik.toml"
        + EmbeddedTmpl: "[entryPoints.http]\naddress = \":{{ env \"NOMAD_ALLOC_PORT_http\" }}\"\n  \n[entryPoints.traefik]\naddress = \":{{ env \"NOMAD_ALLOC_PORT_dashboard\" }}\"\n  \n[api]\ndashboard = true\ninsecure = true\n  \n[providers.consulCatalog]\nprefix = \"hello-world-lb\"\nexposedByDefault = false\n  \n[providers.consulCatalog.endpoint]\naddress = \"{{ env \"CONSUL_HTTP_ADDR\" }}\"\nscheme = \"http\"\n"
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

Alright this looks like it should work.

## Run our updated `hello-world` Job
```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.hcl ./1_HELLO_WORLD/job.hcl
```

## Browse to our new Traefik load-balancer
- Open http://localhost:8080 and ensure that you're being greeted
- Open http://localhost:8081 and ensure that it loads succesfully

## Inspect the Consul provided backend configuration via the Traefik dashboard
- Open:
  http://localhost:8081/dashboard/#/http/services/hello-world@consulcatalog
- You should find your 2 existing `greeter` allocations listed by their full
  address (`<hostname>:<port>`).

## Perform some scaling of our `greeter` allocations 
It's time to scale our `greeter` allocations again, except this time we have a
load-balancer that will reconfigure itself when the count is increased.

- You can scale allocations via the job specification but you can also
  temporarily scale a given `job >> group` via the nomad CLI:
  ```shell
  $ nomad job scale "hello-world" "greeter" 3
  ```
- Refresh:
  http://localhost:8081/dashboard/#/http/services/hello-world@consulcatalog
- You should see 3 `greeter` allocations
- You can also temporarily de-scale a given `job >> group` via the nomad CLI:
  ```shell
  $ nomad job scale "hello-world" "greeter" 2
  ```
- Refresh:
  http://localhost:8081/dashboard/#/http/services/hello-world@consulcatalog
- You should see 2 `greeter` allocations like before

🎉 All done for now, excellent work! 💪🏻
