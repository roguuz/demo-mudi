terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "demo-mudi"

    workspaces {
      name = "demo-mudi"
    }
  }
}