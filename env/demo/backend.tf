terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "demo-boundless"

    workspaces {
      name = "demo-boundless"
    }
  }
}