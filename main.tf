locals {
  secret_name    = "${var.namespace}/${var.job_name}/users"
  volume_name    = "${var.job_name}-data"
  passwords      = { for u in var.users : u => random_password.user[u].result }
  secret_version = parseint(substr(sha256(jsonencode(local.passwords)), 0, 8), 16)
}

resource "random_password" "user" {
  for_each = toset(var.users)
  length   = 32
  special  = false
}

resource "vault_kv_secret_v2" "users" {
  mount                = var.vault_kv_path
  name                 = local.secret_name
  data_json_wo         = jsonencode(local.passwords)
  data_json_wo_version = local.secret_version
}

resource "nomad_dynamic_host_volume" "data" {
  name      = local.volume_name
  namespace = var.namespace
  plugin_id = "mkdir"

  parameters = {
    mode = "0700"
    uid  = "0"
    gid  = "0"
  }

  capability {
    access_mode     = "single-node-writer"
    attachment_mode = "file-system"
  }
}

resource "nomad_job" "nats" {
  jobspec = templatefile("${path.module}/templates/nats.nomad.hcl.tftpl", {
    job_name         = var.job_name
    namespace        = var.namespace
    datacenters      = var.datacenters
    volume_name      = nomad_dynamic_host_volume.data.name
    secret_path      = "${var.vault_kv_path}/data/${local.secret_name}"
    secret_version   = local.secret_version
    internal_network = var.internal_host_network
    image            = var.image
    config           = var.config
    users            = var.users
    client_port      = var.client_port
    monitor_port     = var.monitor_port
    resources        = var.resources
  })

  purge_on_destroy = true

  depends_on = [vault_kv_secret_v2.users]
}
