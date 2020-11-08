variable "project_id" {
}

variable "location" {
  default = "US"
}

variable "cdn_domain" {
}

variable "managed_zone" {
}

variable "bucket_name" {
}

variable "path_rules" {
  default = []
}

variable "unique_prefix" {
}

# with this, might not need to do the path matching?
variable "managed_zone_name" {
  default = ""
}
