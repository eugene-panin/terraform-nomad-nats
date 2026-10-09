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
