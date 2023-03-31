variable "application" {
  type = string
  default = "myapplication"
}

variable "db_name" {
  type = string
}

locals {
  vpc_name = "sandbox-stg"
}

