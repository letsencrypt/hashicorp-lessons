# Getting Started

Start the Consul server in `dev` mode:
```shell
$ consul agent -dev -datacenter dev-general -log-level ERROR
```

Start the Nomad server in `dev` mode:
```shell
$ sudo nomad agent -dev -bind 0.0.0.0 -log-level ERROR -dc dev-general
```

Start a Nomad job deployment:
```shell
$ nomad job run -verbose -var-file=./example/vars-file.hcl ./example/job-specification.hcl
```

- Open the Nomad UI: http://localhost:4646/ui
- Open the Consul UI: http://localhost:8500/ui# hashicorp-lessons
