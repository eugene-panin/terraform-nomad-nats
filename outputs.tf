output "job_id" {
  description = "ID of the NATS job in Nomad."
  value       = nomad_job.nats.id
}

output "service_name" {
  description = "Consul service name clients reach NATS by."
  value       = var.job_name
}

output "client_port" {
  description = "Port NATS serves clients on."
  value       = var.client_port
}

output "users" {
  description = "NATS user names a password was generated for."
  value       = var.users
}

output "credentials_secret" {
  description = "Vault KV name (under the mount) holding each user's password, keyed by user. A client reads its own from here."
  value       = local.secret_name
}

output "data_volume" {
  description = "Name of the dynamic host volume holding the JetStream store."
  value       = nomad_dynamic_host_volume.data.name
}
