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
2. Open the Consul UI: http://localhost:8500/ui

### Start a Nomad job deployment:
```shell
$ nomad job run -verbose -var-file=./1_Hello_World_Vars.hcl ./1_Hello_World
```
