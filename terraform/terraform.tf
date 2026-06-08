###############################################################################
# Terraform settings + required providers
#
# PERSONAL ACCOUNT: state is stored in a NEW S3 bucket that YOU own.
#   1. Create the bucket FIRST (one-time), in the same region:
#        aws s3 mb s3://<YOUR_BUCKET> --region ap-south-1
#   2. Replace <YOUR_TFSTATE_BUCKET> below with that exact name.
#   3. terraform init   (will initialize the S3 backend)
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

  # --- S3 remote backend (state stored in YOUR bucket) ------------------------
  # ⚠️ REPLACE the bucket name below, then run `terraform init`.
  backend "s3" {
    bucket       = "easyshop-tfstate-sayajirao"
    key          = "eks/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
  # ----------------------------------------------------------------------------
}
