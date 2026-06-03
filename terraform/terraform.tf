###############################################################################
# Terraform settings + required providers
#
# NOTE (replica): Using LOCAL state for simplicity (terraform.tfstate on disk).
# The original S3 remote backend is kept below but COMMENTED OUT. To switch to
# S3 later, create the bucket first, then uncomment and run `terraform init`.
###############################################################################

terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # --- S3 remote backend (state stored in your bucket) ------------------------
  backend "s3" {
    bucket       = "k8s-buckettttt"
    key          = "eks/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
  # ----------------------------------------------------------------------------
}
