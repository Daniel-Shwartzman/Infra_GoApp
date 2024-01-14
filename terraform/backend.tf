terraform {
    backend "s3" {
        bucket = "terraform-backend-go-app"
        key    = "network/terraform.tfstate"
        region = "us-east-1"
    }
}