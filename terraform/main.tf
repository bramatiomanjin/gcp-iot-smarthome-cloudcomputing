terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "iam" {
  source         = "./modules/iam"
  project_id     = var.project_id
}

module "security" {
  source         = "./modules/security"
  project_id     = var.project_id
  project_number = var.project_number
  region         = var.region
}