# destination bucket for resized public photos
resource "google_storage_bucket" "resized_photos" {
  name     = var.bucket_name
  location = var.location
  project  = var.project_id
}

# make the bucket public
resource "google_storage_bucket_iam_member" "all_users_viewers" {
  bucket = google_storage_bucket.resized_photos.name
  role   = "roles/storage.legacyObjectReader"
  member = "allUsers"
}

# backend for the bucket
resource "google_compute_backend_bucket" "cdn_backend_bucket" {
  name        = "${var.unique_prefix}-cdn-backend-buck"
  description = "Backend bucket for serving static content through CDN"
  bucket_name = google_storage_bucket.resized_photos.name
  enable_cdn  = true
  project     = var.project_id
}

# url map config
# both buckets will be tied to the ldphoto co domain
# attempting to match "staging" for the staging backend
resource "google_compute_url_map" "cdn_url_map" {
  name        = "${var.unique_prefix}-cdn-url-map"
  description = "CDN URL map to cdn_backend_bucket"
  # wonder if this is required, would unset for staging?
  default_service = google_compute_backend_bucket.cdn_backend_bucket.self_link
  project         = var.project_id

  # this was fun to write, but maybe subdomains to buckets is easier.
  # static-<env> or ldphoto-static, pdphoto-static-staging
  # dynamic "host_rule" {
  #   for_each = var.path_rules
  #   content {
  #     hosts        = [var.cdn_domain]
  #     path_matcher = "env-matcher"
  #   }
  # }

  # dynamic "path_matcher" {
  #   for_each = var.path_rules
  #   content {
  #     name            = "env-matcher"
  #     default_service = google_compute_backend_bucket.cdn_backend_bucket.self_link

  #     path_rule {
  #       paths   = var.path_rules
  #       service = google_compute_backend_bucket.cdn_backend_bucket.self_link
  #     }

  #     # can only specify one
  #     # route_rules {
  #     #   priority = 1
  #     #   url_redirect {
  #     #     path_redirect = "/"
  #     #   }
  #     # }
  #   }
  # }
}

# google managed cert for the proxy
resource "google_compute_managed_ssl_certificate" "cdn_certificate" {
  provider = google-beta
  project  = var.project_id
  name     = "${var.unique_prefix}-cdn-managed-certificate"

  managed {
    domains = ["${var.managed_zone_name}${var.cdn_domain}"]
  }
}

# create proxy
resource "google_compute_target_https_proxy" "cdn_https_proxy" {
  name             = "${var.unique_prefix}-cdn-https-proxy"
  url_map          = google_compute_url_map.cdn_url_map.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.cdn_certificate.self_link]
  project          = var.project_id
}

# ------------------------------------------------------------------------------
# CREATE A GLOBAL PUBLIC IP ADDRESS
# ------------------------------------------------------------------------------

resource "google_compute_global_address" "cdn_public_address" {
  name         = "${var.unique_prefix}-cdn-public-address"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
  project      = var.project_id
}

# ------------------------------------------------------------------------------
# CREATE A GLOBAL FORWARDING RULE
# ------------------------------------------------------------------------------

resource "google_compute_global_forwarding_rule" "cdn_global_forwarding_rule" {
  name       = "${var.unique_prefix}-cdn-global-forw-rule"
  target     = google_compute_target_https_proxy.cdn_https_proxy.self_link
  ip_address = google_compute_global_address.cdn_public_address.address
  port_range = "443"
  project    = var.project_id
}


# everything above this works per-env, where to put the below
# maybe networking takes a remote off of this and the rrdatas have both envs?
# give cross-project permissions?
# move this stuff to the networking workspace?
# how to do one per env?

# DNS record set
# might move this to the networking project?
# probably not a good idea
resource "google_dns_record_set" "cdn_dns_a_record" {
  managed_zone = var.managed_zone # Name of your managed DNS zone
  name         = "${var.managed_zone_name}${var.cdn_domain}."
  type         = "A"
  ttl          = 3600 # 1 hour
  rrdatas      = [google_compute_global_address.cdn_public_address.address]
  project      = var.project_id
}
