variable "vault_kv_path" {
  description = "Path of the Vault KV v2 engine the per-user passwords are kept in; the platform gives it."
  type        = string
}

variable "config" {
  description = <<-EOT
    The NATS server configuration (nats.conf), verbatim. It enables JetStream on
    /data and names the users. Reference each user's password in it as the
    environment variable NATS_<USER>_PASSWORD (upper-case); NATS interpolates it at
    start. Keep it in sync with the users variable.
  EOT
  type        = string
}

variable "users" {
  description = "NATS user names. A password is generated for each and kept in Vault; the job passes it to the server as NATS_<USER>_PASSWORD, and a client reads its own from the same Vault secret."
  type        = list(string)
  validation {
    condition     = alltrue([for u in var.users : can(regex("^[a-z][a-z0-9_]*$", u))])
    error_message = "each user must be lowercase letters, digits and _, starting with a letter."
  }
}

variable "namespace" {
  description = "Nomad namespace the job runs in."
  type        = string
  default     = "default"
}

variable "job_name" {
  description = "Name of the Nomad job and the Consul service other apps reach it by."
  type        = string
  default     = "nats"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}$", var.job_name))
    error_message = "job_name must be lowercase letters, digits and -, starting with a letter."
  }
}

variable "datacenters" {
  description = "Nomad datacenters the job may run in."
  type        = list(string)
  default     = ["*"]
}

variable "image" {
  description = "NATS container image, pinned by a fixed tag or a digest."
  type        = string
  default     = "nats:2.11-alpine"
}

variable "client_port" {
  description = "Port NATS serves clients on, on the internal host network."
  type        = number
  default     = 4222
}

variable "monitor_port" {
  description = "Port NATS serves its monitoring and health endpoints on."
  type        = number
  default     = 8222
}

variable "internal_host_network" {
  description = "Nomad host network NATS binds to. Never the public network: the bus is reachable only inside the platform."
  type        = string
  default     = "default"
}

variable "resources" {
  description = "CPU (MHz) and memory (MB) for the NATS task."
  type = object({
    cpu    = optional(number, 300)
    memory = optional(number, 512)
  })
  default = {}
}
