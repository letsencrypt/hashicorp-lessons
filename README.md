## Getting Started with Hashicorp Nomad and Consul

### Why write another learning guide?
The official [Nomad learning guides](https://learn.hashicorp.com/nomad) provide excellent examples for deploying workloads with Docker but very few showcase orchestration of non-containerized workloads. As a result of this I actually found it a little tough to get some of my first jobs spun-up.

### Install Consul and Nomad
1. https://learn.hashicorp.com/tutorials/consul/get-started-install
1. https://learn.hashicorp.com/tutorials/nomad/get-started-install

### Get Consul and Nomad started in dev mode
Both the `nomad` and `consul` binaries will run in the foreground by default. This is great because you can watch log lines as they come in and troubleshoot any issues encountered while working through these workshops. However, this also means you'll want to use `tmux` or using some kind of native tab or window management to keep these running in a session other than the one you'll be using to edit, plan, and run Nomad jobs.

1. Start the Consul server in `dev` mode:
   ```shell
   $ consul agent -dev -datacenter dev-general -log-level ERROR
   ```
1. Start the Nomad server in `dev` mode:
   ```shell
   $ sudo nomad agent -dev -bind 0.0.0.0 -log-level ERROR -dc dev-general
   ```

### Ensure you can access the Consul and Nomad web UIs
1. Open the Consul web UI: http://localhost:8500/ui
1. Open the Nomad web UI: http://localhost:4646/ui

### Clone the letsencrypt/hashicorp-lessons repository
This repository contains both the starting job specification and examples of how your specification should look after we complete each of the workshops.

### Scan through this commented job specification
Don't worry if it feels like a lot, _it is_. It took me a few days of working with Nomad and Consul to get a good sense of what each of these stanzas was actually doing. Feel free to move forward even if you feel a little lost. You can always come back and reference it as needed.

```hcl
// 'variable' stanzas are used to declare variables that a job specification can
// have passed to it via '-var' and '-var-file' options on the nomad command
// line.
//
// https://www.nomadproject.io/docs/job-specification/hcl2/variables
variable "config-yml-template" {
  type = string
}

// 'job' is the top-most configuration option in the job specification.
//
// https://www.nomadproject.io/docs/job-specification/job
job "hello-world" {

  // datacenters where you would like the hello-world to be deployed.
  //
  // https://www.nomadproject.io/docs/job-specification/job#datacenters
  datacenters = ["dev-general"]

  // 'type' of Scheduler that Nomad will use to run and update the 'hello-world'
  // job. We're using 'service' in this example because we want the
  // 'hello-world' job to be run persistently and restarted if it becomes
  // unhealthy or stops unexpectedly.
  //
  // https://www.nomadproject.io/docs/job-specification/job#type
  type = "service"

  // 'group' is a series of tasks that should be co-located (deployed) on the
  // same Nomad client. 
  //
  //https://www.nomadproject.io/docs/job-specification/group
  group "greeter" {
    // 'count' is the number of allocations (instances) of the 'hello-world'
    // 'greeter' tasks you want to be deployed.
    //
    // https://www.nomadproject.io/docs/job-specification/group#count
    count = 1

    // 'network' declares which ports need to be available on a given Nomad
    // client before it can allocate (deploy an instance of) the 'hello-world'
    // 'greeter'
    //
    // https://www.nomadproject.io/docs/job-specification/network
    network {
      // https://www.nomadproject.io/docs/job-specification/network#port-parameters
      port "http" {
        static = 1234
      }
    }

    // 'service' tells Nomad how the 'hello-world' 'greeter' allocations should be
    // advertised (as a service) in Consul and how Consul should determine that
    // each hello-world greeter allocation is healthy enough to advertise as
    // part of the Service Catalog.
    //
    // https://www.nomadproject.io/docs/job-specification/service
    service {
      name = "hello-world-greeter"
      port = "http"

      // 'check' is the check used by Consul to assess the health or readiness
      // of an individual 'hello-world' 'greeter' allocation.
      //
      // https://www.nomadproject.io/docs/job-specification/service#check
      check {
        name     = "ready-tcp"
        type     = "tcp"
        port     = "http"
        interval = "3s"
        timeout  = "2s"
      }

      // 'check' same as the above except the status of the service depends on
      // the HTTP response code: any 2xx code is considered passing, a 429 Too
      // ManyRequests is warning, and anything else is a failure.
      check {
        name     = "ready-http"
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "3s"
        timeout  = "2s"
      }
    }

    // 'task' defines an individual unit of work for Nomad to schedule and
    // supervise (e.g. a web server, a database server, etc).
    //
    // https://www.nomadproject.io/docs/job-specification/task
    task "greet" {
      // 'driver' is the Task Driver that Nomad should use to execute our
      // 'task'. For shell commands and scripts there are two options:
      //
      // 1. 'raw_exec' is used to execute a command for a task without any
      //    isolation. The task is started as the same user as the Nomad
      //    process. Ensure the Nomad process user is sufficiently restricted in
      //    Production settings.
      // 2. 'exec' uses the underlying isolation primitives of the operating
      //    system to limit the task's access to resources
      // 3. There are many more here: https://www.nomadproject.io/docs/drivers
      //
      // https://www.nomadproject.io/docs/job-specification/task#driver 
      driver = "raw_exec"

      config {
        // 'command' is the binary or script that will be called with /bin/sh.
        command = "greet"
        
        // 'args' is a list of arguments passed to the 'greet' binary.
        args = [
          "-c", "${NOMAD_ALLOC_DIR}/config.yml"
        ]
      }

      // 'template' instructs the Nomad Client to use 'consul-template' to
      // template a given file into the allocation at a specified path. Note:
      // that while 'consul-template' has 'consul' in the name, 'consul' is not
      // required to use it.
      // https://www.nomadproject.io/docs/job-specification/task#template
      // https://www.nomadproject.io/docs/job-specification/template
      template {
        // 'data' is a string containing the contents of the consul template.
        // Here we're passing a variable instead of defining it inline but both
        // are perfectly valid.
        data        = var.config-yml-template
        destination = "${NOMAD_ALLOC_DIR}/config.yml"
        change_mode = "restart"
      }

      // 'env' allows us to pass environment variables to our task. Since
      // consul-template is run locally inside of allocation, if we needed to
      // pass a variable from our job specification we would need to pass them
      // in this stanza.
      // https://www.nomadproject.io/docs/job-specification/task#env
      //
      env {
        // 'foo' is just an example and not actually used in these lessons.
        foo = "${var.foo}"
      }
    }
  }
}
```

## Nomad Workshop 1 - Hello World
In 'getting started' we got Nomad and Consul installed and reviewed each stanza of a Nomad job specification. In this workshop we're going to deploy a 'Hello World' style app, make some changes to it's configuration, and then re-deploy it.

### Install the `greet` binary
These lessons make use of `greet`, a simple web server that will respond with _Hello, `<name>`_ when you send it an HTTP GET request. Ensure that you've got it installed before continuing.

If you've got Go `v1.17` installed and your `$GOPATH` in you `$PATH` then you should be able to `go install` it like so:
                           
```shell
$ go install github.com/letsencrypt/hashicorp-lessons/greet@latest
```

Ensure greet is now in our `$PATH`.

```shell
$ which greet
```

### Check the plan output for the _hello-world_ job
Running the `plan` subcommand will help us understand what actions the Nomad
Scheduler is going to take on our behalf. Now you're probably seeing a whole lot of changes here that were not included in our job specification. This is because, in the absence of their explicit definition, Nomad will fill in some defaults for required values.

```hcl
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.go ./1_HELLO_WORLD/job.go
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
    + Name:              "hello-world-greeter"
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
  + Task: "greet" (forces create)
    + Driver:        "raw_exec"
    + KillTimeout:   "5000000000"
    + Leader:        "false"
    + ShutdownDelay: "0"
    + Config {
      + args[0]: "-c"
      + args[1]: "${NOMAD_ALLOC_DIR}/config.yml"
      + command: "greet"
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
      + DestPath:     "${NOMAD_ALLOC_DIR}/config.yml"
      + EmbeddedTmpl: "---\nname: \"Samantha\"\nport: 1234\n\n"
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

### Run the _hello-world_ job
We expect that running our job should succeed because the `plan` output above stated that all of our tasks would be successfully allocated. Let's find out!

```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.go ./1_HELLO_WORLD/job.go
```

### Visit the the greeter URL in your browser
1. Open http://localhost:1234
1. You should see:
   ```
   Hello, Samantha
   ```

### For our first change, let's make it greet you, instead of me
Edit the value of `name` in `1_HELLO_WORLD/vars.go`:

```yaml
---
name: "YOUR NAME"
port: 1234

```

### Check the plan output for the _hello-world_ job
```shell
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.go ./1_HELLO_WORLD/job.go
+/- Job: "hello-world"
+/- Task Group: "greeter" (1 create/destroy update)
  +/- Task: "greet" (forces create/destroy update)
    +/- Template {
          ChangeMode:   "restart"
          ChangeSignal: ""
          DestPath:     "${NOMAD_ALLOC_DIR}/config.yml"
      +/- EmbeddedTmpl: "---\nname: \"Samantha\"\nport: 1234\n\n" => "---\nname: \"YOUR NAME\"\nport: 1234\n\n"
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

Looks like it's going to work out just fine!

### Deploy our updated _hello-world_ job
```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.go ./1_HELLO_WORLD/job.go
```

### Visit the the _greeter_ URL in your browser
1. Open [http://localhost:1234](http://localhost:1234)
1. You should see:
   ```
   Hello, YOUR NAME
   ```

## Nomad Workshop 2 - Scaling Allocations
It's time to scale our greeter allocations. Thankfully Nomad's dynamic port allocation and Consul's templating are going to make this operation pretty painless.

It's best if you follow the documentation here to update your job specification at `1_HELLO_WORLD/job.go` and your vars file at `1_HELLO_WORLD/vars.go`, but if you get lost you can see the final product under `2_HELLO_SCALING/job.go` and `2_HELLO_SCALING/vars.go`.

### Increment the _greeter_ count in our job specification
Edit `job >> group "greeter" >> count` in our job specification from:
```hcl
count = 1
```

to:
```hcl
count = 2
```

### Check the plan output for the _hello-world_ job
```shell
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.go ./1_HELLO_WORLD/job.go
+/- Job: "hello-world"
+/- Task Group: "greeter" (1 create, 1 in-place update)
  +/- Count: "1" => "2" (forces create)
      Task: "server"

Scheduler dry-run:
- WARNING: Failed to place all allocations.
  Task Group "greeter" (failed to place 1 allocation):
    1. Resources exhausted on 1 nodes
    1. Dimension "network: reserved port collision http=1234" exhausted on 1 nodes
```

It looks like having a static port of `1234` is going to cause resource exhaustion. Not to worry though, we can update our job specification to let the Nomad Scheduler pick a port for each of our _greeter_ allocations to listen on.

### Update the job to make port selection dynamic
Under `job >> group "greeter" >> network >> port` we can remove our static port assignment of _1234_ and leave empty curly braces _{}_ . This will instruct the Nomad Scheduler dynamically assign the port for each allocation.

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

### Update our _greet_ config file template to use a dynamic port
By replacing _1234_ in our _greet_ config template with the `NOMAD_ALLOC_PORT_http` environment variable Nomad will always keep our config file up-to-date.

We expect the environment variable to be `NOMAD_ALLOC_PORT_http` because the network port we declare at `job >> group "greeter" >> network >> port` is called `http` . If we had called it `my-special-port` we would use `NOMAD_ALLOC_PORT_my-special-port`.

Our existing line:
```hcl
port: 1234
```

Our new line:
```hcl
port: {{ env "NOMAD_ALLOC_PORT_http" }}
```

For more info on Nomad Runtime Environment Variables see these
[docs](https://www.nomadproject.io/docs/runtime/environment).

### Check the plan output of the updated _hello-world_ job
```shell
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.go ./1_HELLO_WORLD/job.go
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
  +/- Task: "greet" (forces create/destroy update)
    +/- Template {
          ChangeMode:   "restart"
          ChangeSignal: ""
          DestPath:     "${NOMAD_ALLOC_DIR}/config.yml"
      +/- EmbeddedTmpl: "---\nname: \"Samantha\"\nport: 1234\n\n" => "---\nname: \"Samantha\"\nport: {{ env \"NOMAD_ALLOC_PORT_http\" }}\n\n"
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

### Run the updated _hello-world_ job
```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.go ./1_HELLO_WORLD/job.go
```

### Fetch the ports of our 2 new _greeter_ allocations
There are a few ways that we can fetch the ports that Nomad assigned to our
_greeter_ allocations.

#### via the Nomad GUI
1. Open: http://localhost:4646/ui/jobs/hello-world/web
1. Scroll down to the **Allocations** table
1. Open each of the **Allocations** where Status is **running**
1. Scroll down to the **Ports** table, and note the value for **http** in the **Host Address** column

#### via the Nomad CLI

1. Run `nomad job status hello-world` and note the **ID** for each allocation with **running** in the **Status** column:
    ```shell
    $ nomad job status hello-world
    ID            = hello-world
    Name          = hello-world
    Submit Date   = 2022-01-06T16:57:57-08:00
    Type          = service
    Priority      = 50
    Datacenters   = dev-general
    Namespace     = default
    Status        = running
    Periodic      = false
    Parameterized = false
    
    Summary
    Task Group  Queued  Starting  Running  Failed  Complete  Lost
    greeter     0       0         2        0       1         0
    
    Latest Deployment
    ID          = a11c023a
    Status      = successful
    Description = Deployment completed successfully
    
    Deployed
    Task Group  Desired  Placed  Healthy  Unhealthy  Progress Deadline
    greeter     2        2       2        0          2022-01-06T17:08:24-08:00
    
    Allocations
    ID        Node ID   Task Group  Version  Desired  Status    Created    Modified
    4ed1c285  e6e7b140  greeter     1        run      running   17s ago    4s ago
    ef0ef9b3  e6e7b140  greeter     1        run      running   31s ago    18s ago
    aa3a7834  e6e7b140  greeter     0        stop     complete  14m9s ago  16s ago
    ```
1. Run `nomad alloc status <allocation-id>` for each alloc _ID_:
   ```shell
   $ nomad alloc status 4ed1c285
   ID                  = 4ed1c285-e923-d627-7cc2-d392147eca2f
   Eval ID             = e6b817a5
   Name                = hello-world.greeter[0]
   Node ID             = e6e7b140
   Node Name           = treepie.local
   Job ID              = hello-world
   Job Version         = 1
   Client Status       = running
   Client Description  = Tasks are running
   Desired Status      = run
   Desired Description = <none>
   Created             = 58s ago
   Modified            = 45s ago
   Deployment ID       = a11c023a
   Deployment Health   = healthy
   
   Allocation Addresses
   Label  Dynamic  Address
   *http  yes      127.0.0.1:31623
 
   Task "greet" is "running"
   Task Resources
   CPU        Memory          Disk     Addresses
   0/100 MHz  49 MiB/300 MiB  300 MiB
   
   Task Events:
   Started At     = 2022-01-07T00:58:12Z
   Finished At    = N/A
   Total Restarts = 0
   Last Restart   = N/A
   
   Recent Events:
   Time                       Type        Description
   2022-01-06T16:58:12-08:00  Started     Task started by client
   2022-01-06T16:58:12-08:00  Task Setup  Building Task Directory
   2022-01-06T16:58:12-08:00  Received    Task received by client
   ```
1. Under **Allocation Addresses** we can see `127.0.0.1:31623` is the address for this allocation

In our job specification you'll see that we also registered our _greeter_ allocations with the Consul Catalog as a Service called _hello-world-greeter_. This means that we can also grab these addresses and ports via the Consul web UI:
1. Open http://localhost:8500/ui/dev-general/services/hello-world-greeter/instances
1. On the right-hand side of each entry you can find the complete IP address and port for each of our _hello-world-greeter_ allocations.

#### via the Consul DNS endpoint
But, how would a service be able to locate these _hello-world-greeter_ allocations? Well sure, you could integrate a Consul Client into these other services that want to connect with a _hello-world-greeter_, but there's something a little simpler that you can do as a first approach, use the DNS endpoint that Consul exposes by default to fetch theses addresses and ports in the form of a `SRV` record.

```shell
$ dig @127.0.0.1 -p 8600 hello-world-greeter.service.dev-general.consul. SRV

; <<>> DiG 9.10.6 <<>> @127.0.0.1 -p 8600 hello-world-greeter.service.dev-general.consul. SRV
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 11398
;; flags: qr aa rd; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 5
;; WARNING: recursion requested but not available

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;hello-world-greeter.service.dev-general.consul.	IN SRV

;; ANSWER SECTION:
hello-world-greeter.service.dev-general.consul.	0 IN SRV 1 1 28098 7f000001.addr.dev-general.consul.
hello-world-greeter.service.dev-general.consul.	0 IN SRV 1 1 31623 7f000001.addr.dev-general.consul.

;; ADDITIONAL SECTION:
7f000001.addr.dev-general.consul. 0 IN	A	127.0.0.1
treepie.local.node.dev-general.consul. 0 IN TXT	"consul-network-segment="
7f000001.addr.dev-general.consul. 0 IN	A	127.0.0.1
treepie.local.node.dev-general.consul. 0 IN TXT	"consul-network-segment="

;; Query time: 0 msec
;; SERVER: 127.0.0.1#8600(127.0.0.1)
;; WHEN: Thu Jan 06 17:01:41 PST 2022
;; MSG SIZE  rcvd: 302
```

Given the output of this `SRV` record you should be able to browse to http://localhost:28098 or http://localhost:31623 and be greeted.

If you follow [these docs](https://learn.hashicorp.com/tutorials/consul/dns-forwarding) you should also be able add Consul to your list of resolvers.

Assuming Consul is set as one of my resolvers I should also be able to browse to either of the following:
- http://hello-world-greeter.service.dev-general.consul:28098
- http://hello-world-greeter.service.dev-general.consul:31623

## Nomad Workshop 3 - Storing Configuration in Consul
Re-deploying hello-world every time we want to change the name we're saying hello to seems a little heavy handed when we really just need to update our greet config file template and restart our greet task. So, how can we accomplish this without another deployment? Consul to the rescue!

It's best if you follow the documentation here to update your job specification at `1_HELLO_WORLD/job.go` and your vars file at `1_HELLO_WORLD/vars.go`, but if you get lost you can see the final product under `3_HELLO_CONSUL/job.go` and `3_HELLO_CONSUL/vars.go`.

Nomad ships with a tool called `consul-template` that we've actually already been making good use of. For example, the _template_ stanza of our _greet_ uses `consul-template` to template our _config.yml_ file.

```hcl
template {
  data        = var.config-yml-template
  destination = "${NOMAD_ALLOC_DIR}/config.yml"
  change_mode = "restart"
}
```

We can instruct `consul-template` to retrieve the name of the person we're saying hello to from the Consul K/V store while deploying our _greeter_ allocations. After an initial deploy, Nomad will then watch the Consul K/V path for changes. If a change is detected, Nomad will re-run `consul-template` with the updated value and then take the action specified by the `change_mode` attribute of our `template` stanza. In our case, it will `restart` the _greet_ task.

### Modify our _greet_ config file template to source from Consul
Our template var in `1_HELLO_WORLD/vars.go` is currently:
```hcl
config-yml-template = <<-EOF
  ---
  name: "YOUR NAME"
  port: {{ env "NOMAD_ALLOC_PORT_http" }}
  
EOF
```

We should edit it like so:
```hcl
config-yml-template = <<-EOF
  {{ with $v := key "hello-world/config" | parseYAML }}
  ---
  name: "{{ $v.name }}"
  port: {{ env "NOMAD_ALLOC_PORT_http" }}
  {{ end }}
  
EOF
```
Here we're setting a variable `v` with the parsed contents of the YAML stored at the Consul K/V path of `hello-world/config`. We're then templating the value of the `name` key.

Note: make sure you leave an empty newline at the end of your vars file otherwise the Nomad CLI won't be able to parse it properly.

### Push our YAML formatted config to Consul
We could do this with the Consul web UI but using the `consul` CLI is much
faster.

```shell
$ consul kv put 'hello-world/config' 'name: "Samantha"'
Success! Data written to: hello-world/config

$ consul kv get 'hello-world/config'
name: "Samantha"
```

Here we've pushed a `name` key with a value of `"Samantha"` to the
`hello-world/config` Consul K/V. We have also fetched it just to be sure.

### Check the plan output for our updated _hello-world_ job
```shell
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.go ./1_HELLO_WORLD/job.go
+/- Job: "hello-world"
+/- Task Group: "greeter" (1 create/destroy update, 1 ignore)
  +/- Task: "greet" (forces create/destroy update)
    +/- Template {
          ChangeMode:   "restart"
          ChangeSignal: ""
          DestPath:     "${NOMAD_ALLOC_DIR}/config.yml"
      +/- EmbeddedTmpl: "---\nname: \"Samantha\"\nport: {{ env \"NOMAD_ALLOC_PORT_http\" }}\n\n" => "{{ with $v := key \"hello-world/config\" | parseYAML }}\n---\nname: \"{{ $v.name }}\"\nport: {{ env \"NOMAD_ALLOC_PORT_http\" }}\n{{ end }}\n  \n"
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

### Run our updated _hello-world_ job
```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.go ./1_HELLO_WORLD/job.go
```

### Let's fetch the ports of our 2 new _greeter_ allocations
```shell
$ dig @127.0.0.1 -p 8600 hello-world-greeter.service.dev-general.consul. SRV | grep hello-world-greeter.service
; <<>> DiG 9.10.6 <<>> @127.0.0.1 -p 8600 hello-world-greeter.service.dev-general.consul. SRV
;hello-world-greeter.service.dev-general.consul.	IN SRV
hello-world-greeter.service.dev-general.consul.	0 IN SRV 1 1 30226 7f000001.addr.dev-general.consul.
hello-world-greeter.service.dev-general.consul.	0 IN SRV 1 1 28843 7f000001.addr.dev-general.consul.
```

You should be able to browse to http://localhost:30226 or http://localhost:28843
and be greeted.

### Update the value of `name` in Consul
```shell
$ consul kv put 'hello-world/config' 'name: "SAMANTHA"'
Success! Data written to: hello-world/config

$ consul kv get 'hello-world/config'
name: "SAMANTHA"
```

### Browse to one of our _greeter_ allocation URLs again
If you reload http://localhost:30226 or http://localhost:28843 you should be greeted by your updated name. This did not require a deployment; Nomad was notified that the value at the Consul K/V path of `hello-world/config` had been updated. Nomad re-templated our _greet_ config file and then restarted our _greet_ task just like we asked (in the `template` stanza).

Note: you may have observed a pause of about 5 seconds between when the _greet_ task being stopped and when it was started again. This is the default wait time between stop and start operations and it's entirely configurable on a per group or task basis.

## Nomad Workshop 4 - Load Balancing with Consul and Traefik
It's time to scale our hello-world job again, but this time we're going to do so with the help of a load balancer called Traefik. Traefik is an open-source edge router written in Go with first-party Consul integration. Please ensure that you've got version 2.5.x installed and in your path.

### Install Traefik
I was able to fetch the binary via Homebrew on MacOS but you can always fetchthe latest binary for your platform from their[releases](https://github.com/traefik/traefik/releases) page.

### Add a Traefik config template to our vars file
Out Traefik config is a minimal TOML file with some consul-template syntax.

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

1. Our first two declarations are HTTP `entryPoints` which are similar to `http { server {` in NGINX parlance. The only attribute we need need to template is the `<hostname>:<port>`. The first is for our _greeter_ load-balancer and the second is for the Traefik dashboard (not required). For both of these we can rely on the Nomad environment variables for two new ports we're going to add to our job specification, these will be called `http` and `dashboard`. Again, we prefix these with `NOMAD_ALLOC_PORT_` and Nomad will do the rest for us.
1. The next declaration is `api`. Here we're just going to enable the `dashboard` and disable `tls`.
1. The final declarations enable and configure the `consulCatalog` provider. There are two attributes in the first declaration. `prefix` configures the provider to exclusively query for Consul catalog hosts tagged with `prefix:hello-world-lb`. `exposedByDefault` (false) configures the provider to query only Consul services tagged with `traefik.enable=true`. The last declaration instructs the provider on how to connect to Consul. Because Nomad and Consul are already tightly integrated we can template `address` with the `CONSUL_HTTP_ADDR` env var. As for `scheme`, since we're using Consul in `dev` mode this is `http`.
1. Ensure that you add a newline at the end of this file otherwise Nomad will be unable to parse it.

### Declare a variable for our Traefik config template in our job specification
Near the top, just below our existing `config-yml-template` variable declaration add the following:

```hcl
variable "traefik-config-template" {
  type = string
}
```

### Add a new group for our load-balancer above _greeter_
Our Traefik load-balancer will route requests on port `8080` to any healthy _greeter_ allocation. Traefik will also expose a dashboard on port `8081`. We've added static ports for both the load-balancer (`http`) and the dashboard under the `network` stanza. We've also added some TCP and HTTP readiness checks that reference these ports in our new _hello-world-lb_ Consul service.

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

### Lastly, add some tags to the _hello-world-greeter_ service
Under the _greeter_ group you should see the `service` stanza. Adjust yours to include the tags from the Traefik config.

```hcl
service {
  name = "hello-world-greeter"
  port = "http"
  tags = [
    "hello-world-lb.enable=true",
    "hello-world-lb.http.routers.http.rule=Path(`/`)",
  ]
```


### Check the plan output for our updated _hello-world_ job
```shell
$ nomad job plan -verbose -var-file=./1_HELLO_WORLD/vars.go ./1_HELLO_WORLD/job.go
+/- Job: "hello-world"
+/- Task Group: "greeter" (2 in-place update)
  +/- Service {
      AddressMode:       "auto"
      EnableTagOverride: "false"
      Name:              "hello-world-greeter"
      Namespace:         "default"
      OnUpdate:          "require_healthy"
      PortLabel:         "http"
      TaskName:          ""
    + Tags {
      + Tags: "hello-world-lb.enable=true"
      + Tags: "hello-world-lb.http.routers.http.rule=Path(`/`)"
      }
      }
      Task: "greet"

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
        + Label:       "dashboard"
        + To:          "0"
        + Value:       "8081"
        }
      + Static Port {
        + HostNetwork: "default"
        + Label:       "http"
        + To:          "0"
        + Value:       "8080"
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

### Run our updated _hello-world_ job
```shell
$ nomad job run -verbose -var-file=./1_HELLO_WORLD/vars.go ./1_HELLO_WORLD/job.go
```

### Browse to our new Traefik load-balancer
1. Open http://localhost:8080 and ensure that you're being greeted
1. Open http://localhost:8081 and ensure that it loads succesfully

### Inspect the Consul provided backend configuration via the Traefik dashboard
1. Open: http://localhost:8081/dashboard/#/http/services/hello-world-greeter@consulcatalog
1. You should find your 2 existing _greeter_ allocations listed by their full address `<hostname>:<port>`.

### Perform some scaling of our _greeter_ allocations 
It's time to scale our _greeter_ allocations again, except this time we have a load-balancer that will reconfigure itself when the count is increased.

1. You can scale allocations via the job specification but you can also temporarily scale a given `job >> group` via the nomad CLI:
   ```shell
   $ nomad job scale "hello-world" "greeter" 3
   ```
1. Refresh: http://localhost:8081/dashboard/#/http/services/hello-world-greeter@consulcatalog
1. You should see 3 _greeter_ allocations
1. You can also temporarily de-scale a given `job >> group` via the nomad CLI:
   ```shell
   $ nomad job scale "hello-world" "greeter" 2
   ```
1. Refresh: http://localhost:8081/dashboard/#/http/services/hello-world-greeter@consulcatalog
1. You should see 2 _greeter_ allocations like before
