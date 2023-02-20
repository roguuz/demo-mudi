terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "upw-demos"

    workspaces {
      name = "demo-mudi"
    }
  }
}