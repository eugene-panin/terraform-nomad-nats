mock_provider "nomad" {}
mock_provider "random" {}
mock_provider "vault" {}

variables {
  vault_kv_path = "secret"
  users         = ["fetcher", "ingest", "ui"]
  config        = <<-EOT
    port: 4222
    http_port: 8222
    jetstream { store_dir: /data }
    authorization {
      users = [
        {user: fetcher, password: $NATS_FETCHER_PASSWORD}
        {user: ingest, password: $NATS_INGEST_PASSWORD}
        {user: ui, password: $NATS_UI_PASSWORD}
      ]
    }
  EOT
}

run "it_exposes_a_consul_service" {
  command = apply

  assert {
    condition     = output.service_name == "nats" && output.client_port == 4222
    error_message = "NATS is not exposed as the expected Consul service and port."
  }

  assert {
    condition     = output.credentials_secret == "default/nats/users"
    error_message = "The credentials are not at the expected Vault name."
  }
}

run "it_injects_a_password_env_per_user_and_stays_internal" {
  command = apply

  assert {
    condition     = strcontains(nomad_job.nats.jobspec, "NATS_FETCHER_PASSWORD={{ .Data.data.fetcher }}")
    error_message = "A user's password is not injected from Vault."
  }

  assert {
    condition     = strcontains(nomad_job.nats.jobspec, "store_dir: /data")
    error_message = "The provided NATS config was not written."
  }

  assert {
    condition     = !strcontains(nomad_job.nats.jobspec, "host_network = \"public\"")
    error_message = "The bus must never bind the public host network."
  }
}
