locals {
  network_name = "gke-autopilot-playground"
  subnet_cidr  = "10.10.0.0/20"
  pods_cidr    = "10.20.0.0/14"
  svc_cidr     = "10.24.0.0/20"
}

resource "google_compute_network" "this" {
  name                     = local.network_name
  auto_create_subnetworks  = false
  enable_ula_internal_ipv6 = true
}

resource "google_compute_subnetwork" "this" {
  name = local.network_name

  ip_cidr_range = local.subnet_cidr
  region        = "europe-west1"

  stack_type       = "IPV4_IPV6"
  ipv6_access_type = "INTERNAL" # Change to "EXTERNAL" if creating an external loadbalancer

  network = google_compute_network.this.id
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = local.svc_cidr
  }

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = local.pods_cidr
  }
}
