# Changelog

## v0.1.0

- NATS with JetStream on a Nomad platform: one job, the store in a dynamic host
  volume the platform's backup copies by name (`meta.backup = "stop"`).
- A Consul service clients reach it by, health-checked on the monitoring port. It
  binds only the internal host network.
- A password is generated per user and kept in Vault; the job passes each to the
  server as `NATS_<USER>_PASSWORD`, and a client reads its own from the same
  secret. The authorization policy is the caller's `config`, so the users and
  their permissions stay with the app that owns them.

## v0.1.1

- The task reserves 256 MB, sized to its use, and may grow to 512 MB:
  `resources.memory_max` (Nomad memory oversubscription, which the platform
  turns on). It reserved more than it used before.

## v0.1.2

- `mesh`: NATS can join the Consul service mesh — an Envoy sidecar with the
  transparent proxy, so mesh services reach it as `<job_name>.virtual.consul`
  over mTLS and only those in `mesh.allow` may (service-intentions; the
  platform's ACLs deny the rest). `mesh.keep_open_ports` stay reachable outside
  the mesh while clients move in; the monitoring port always is. Envoy's metrics
  are a `<job_name>-envoy` service tagged for the platform's Alloy.
