terraform {
  backend "s3" {
    bucket         = "terraform-state-925185632967"
    key            = "stacks/builds/app10/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
