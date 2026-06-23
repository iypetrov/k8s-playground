locals {
  k8s_name = "gke-autopilot-playground"
}

resource "google_container_cluster" "this" {
  name = local.k8s_name

  location                 = "europe-west1"
  enable_autopilot         = true
  enable_l4_ilb_subsetting = true

  network    = google_compute_network.this.id
  subnetwork = google_compute_subnetwork.this.id

  ip_allocation_policy {
    stack_type                    = "IPV4_IPV6"
    services_secondary_range_name = google_compute_subnetwork.this.secondary_ip_range[0].range_name
    cluster_secondary_range_name  = google_compute_subnetwork.this.secondary_ip_range[1].range_name
  }

  # Only for testing
  deletion_protection = false
}
