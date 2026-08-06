variable "account_id" { type = string }
variable "api_key" { type = string }

variable "region" {
  type    = string
  default = "US"
}

variable "hostname" {
  type    = string
  default = "workshopaqm-infra"
}

variable "appname" {
  type    = string
  default = "workshopaqm-app"
}

variable "email" {
  type    = string
  default = "workshop@example.com"
}

variable "account_type" {
  type    = string
  default = "paid"
}
