terraform {
  required_version = ">=1.0"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = ">=0.31.0"
    }
  }
}