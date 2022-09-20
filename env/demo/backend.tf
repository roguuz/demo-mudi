terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "Boundless"

    workspaces {
      name = "demo"
    }
  }
}