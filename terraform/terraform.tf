terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region        = "us-east-1"
  access_key    = #ADD Access Key
  secret_key    = #ADD Secret Access Key
  token         = #Optionally add Session token
}