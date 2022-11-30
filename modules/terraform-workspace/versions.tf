terraform {
  required_version = ">=1.3.0"

  required_providers {
    assert = {
      source  = "bwoznicki/assert"
      version = ">=0.0.1"
    }

    utils = {
      source  = "cloudposse/utils"
      version = ">=1.0.0"
    }
  }
}
