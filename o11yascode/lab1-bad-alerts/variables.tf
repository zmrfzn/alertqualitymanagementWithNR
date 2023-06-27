# your unique New Relic account ID 
variable "account_id" {
  default = "INSERT YOUR NR ACCOUNT ID"
}

# your User API key
variable "api_key" {
  default = "INSERT YOUR NR USER KEY"
}

# valid regions are US and EU
variable "region" {
  default = "US"
}

# your unique New Relic App ID 
variable "appname" {
  default = "workshopaqm-app"
}

# your unique New Relic App ID 
variable "hostname" {
  default = "workshopaqm-infra"
}

# your email address to send notification 
variable "email" {
  default = "username@example.com"
}