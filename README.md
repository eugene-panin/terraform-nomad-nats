# terraform-nomad-nats

NATS with JetStream on a Nomad platform that has Consul and Vault — such as
[hashi](https://github.com/eugene-panin/damstack-hashi). The
[damstack-nats](https://github.com/eugene-panin/damstack-nats) stack wires it.

A generic server: it runs NATS with the `config` you give it, keeps the
JetStream store in a host volume, and exposes a Consul service. The
authorization policy — the users and what each may publish, subscribe and do on
JetStream — is your `config`, because that belongs to the app that owns the bus
(e.g. Sauron). The server knows only the user names, to inject their passwords.

## What it deploys

- One Nomad job, NATS, the JetStream store in the `<job_name>-data` host volume
  (`meta.backup = "stop"`).
- A Consul service `<job_name>` on `client_port`, health-checked on the
  monitoring port, bound to the internal host network.
- A password per user in Vault at `<vault_kv_path>/<namespace>/<job_name>/users`,
  keyed by user. The job passes each to NATS as `NATS_<USER>_PASSWORD`; a client
  reads its own from the same secret.

## Inputs

| Name | Default | What |
| --- | --- | --- |
| `vault_kv_path` | — | Vault KV v2 mount the platform gives |
| `config` | — | the `nats.conf`, verbatim; reference passwords as `$NATS_<USER>_PASSWORD` |
| `users` | — | user names a password is generated for |
| `job_name` | `nats` | Nomad job and Consul service name |
| `namespace` | `default` | Nomad namespace |
| `datacenters` | `["*"]` | Nomad datacenters |
| `image` | `nats:2.11-alpine` | NATS image, pinned |
| `client_port` | `4222` | client port on the internal network |
| `monitor_port` | `8222` | monitoring/health port |
| `internal_host_network` | `default` | host network it binds to |
| `resources` | `{300, 512}` | `{cpu, memory}` |
| `service_tags` | `[]` | tags of the Consul service, such as `damstack.provides=<capability>` |
| `service_meta` | `{}` | meta of the Consul service, what else a client needs |

## Outputs

`job_id`, `service_name`, `client_port`, `users`, `credentials_secret` (Vault
name), `data_volume`.

## Development

```sh
make lint
make module-tests
```

## Service mesh

With `mesh.enabled`, the job gets an Envoy sidecar (transparent proxy) and
Consul config entries: `service-defaults` (`mesh.protocol`, tcp) and
`service-intentions` allowing only `mesh.allow`. Mesh clients connect to
`nats://<job_name>.virtual.consul:4222`. While some clients are not in the mesh
yet, keep `4222` in `mesh.keep_open_ports`; drop it once they all are. The
monitoring port stays open for the health check.
