# your unique New Relic account ID 
variable "account_id" {
  default = "XXXXXX"
}

# your User API key
variable "api_key" {
  default = "XXXXXX"
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

# env var "TF_VAR_account_type=free" required to prevent entitlement issues with enrichments
variable "account_type" {
    type = string
    default = "free"
}