terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5"
}

provider "google" {
  project = "project-75f92f7c-c9ed-4db3-9cc"
  region  = "us-central1"
  zone    = "us-central1-a"
}

resource "google_compute_network" "cloudeco_vpc" {
  name                    = "cloudeco-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "cloudeco_subnet" {
  name          = "cloudeco-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = "us-central1"
  network       = google_compute_network.cloudeco_vpc.id
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "cloudeco-allow-ssh"
  network = google_compute_network.cloudeco_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "cloudeco-allow-internal"
  network = google_compute_network.cloudeco_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/24"]
}

resource "google_compute_firewall" "allow_http" {
  name    = "cloudeco-allow-http"
  network = google_compute_network.cloudeco_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "8000", "30000-32767"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["cloudeco-node"]
}

locals {
  nodes = {
    master  = { role = "master" }
    worker1 = { role = "worker" }
    worker2 = { role = "worker" }
  }
}

resource "google_compute_instance" "k8s_nodes" {
  for_each     = local.nodes
  name         = "cloudeco-${each.key}"
  machine_type = "n2-standard-4"
  zone         = "us-central1-a"
  tags         = ["cloudeco-node"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.cloudeco_subnet.id
    access_config {}
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/gcp_key.pub")}"
  }
}

output "master_ip" {
  value = google_compute_instance.k8s_nodes["master"].network_interface[0].access_config[0].nat_ip
}

output "worker1_ip" {
  value = google_compute_instance.k8s_nodes["worker1"].network_interface[0].access_config[0].nat_ip
}

output "worker2_ip" {
  value = google_compute_instance.k8s_nodes["worker2"].network_interface[0].access_config[0].nat_ip
}
