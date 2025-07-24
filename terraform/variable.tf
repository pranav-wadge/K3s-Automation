variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID of the root domain (e.g. pranavwadge.cloud)"
  type        = string
}

variable "domain_name" {
  description = "Subdomain to point to the EC2 instance (e.g. shoes.pranavwadge.cloud)"
  type        = string
}
