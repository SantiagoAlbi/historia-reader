terraform {
  backend "s3" {
    bucket       = "historia-reader-tfstate-praga"
    key          = "historia-reader/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
