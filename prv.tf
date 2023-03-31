provider "aws" {
  region = "eu-west-2"
}

#s3 provider
terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
