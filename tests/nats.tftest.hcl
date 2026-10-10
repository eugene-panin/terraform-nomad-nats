mock_provider "consul" {}
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

run "memory_is_reserved_by_use_and_may_grow" {
  command = apply

  assert {
    condition     = strcontains(nomad_job.nats.jobspec, "memory     = 256") && strcontains(nomad_job.nats.jobspec, "memory_max = 512")
    error_message = "The task must reserve its usual memory and be allowed to grow to memory_max."
  }
}

run "it_joins_the_mesh" {
  command = apply

  variables {
    mesh = { enabled = true, allow = ["sauron-fetcher", "sauron-ingest"], keep_open_ports = [4222] }
  }

  assert {
    condition = (
      strcontains(nomad_job.nats.jobspec, "transparent_proxy")
      && strcontains(nomad_job.nats.jobspec, "exclude_inbound_ports = [\"4222\",\"8222\",\"9102\"]")
      && strcontains(nomad_job.nats.jobspec, "name     = \"nats-envoy\"")
      && strcontains(nomad_job.nats.jobspec, "uid                   = \"1337\"")
    )
    error_message = "In the mesh NATS must sit behind an Envoy sidecar, keep the given ports and its monitoring open, and expose Envoy's metrics."
  }

  assert {
    condition = (
      jsondecode(consul_config_entry.intentions[0].config_json).Sources == [{ Name = "sauron-fetcher", Action = "allow", Precedence = 9, Type = "consul" }, { Name = "sauron-ingest", Action = "allow", Precedence = 9, Type = "consul" }]
      && jsondecode(consul_config_entry.defaults[0].config_json).Protocol == "tcp"
    )
    error_message = "Only the allowed services may connect, and the protocol is tcp."
  }
}

run "out_of_the_mesh_by_default" {
  command = apply

  assert {
    condition     = !strcontains(nomad_job.nats.jobspec, "connect {") && length(consul_config_entry.intentions) == 0
    error_message = "Without mesh.enabled there is no sidecar and no intentions."
  }
}

run "in_the_mesh_the_port_is_static_only_while_kept_open" {
  command = apply

  variables {
    mesh = { enabled = true, allow = ["x"] }
  }

  assert {
    condition     = !strcontains(nomad_job.nats.jobspec, "static       = 4222")
    error_message = "Nomad lets a static port bypass the sidecar: in the mesh the client port must be dynamic unless kept open."
  }
}

run "envoy_passes_to_the_port_inside_the_group" {
  command = apply

  variables {
    mesh = { enabled = true, allow = ["x"] }
  }

  assert {
    condition     = strcontains(nomad_job.nats.jobspec, "local_service_port = ")
    error_message = "With a dynamic port, Envoy must be told the port inside the group, or it passes the traffic to the host port, where nothing listens."
  }
}
