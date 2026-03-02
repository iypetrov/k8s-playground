variable "aws_access_key_id" {
  type      = string
  sensitive = true
}

variable "aws_secret_access_key" {
  type      = string
  sensitive = true
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "zone_id" {
  type      = string
  sensitive = true
}

variable "domain_name" {
  type    = string
  default = "ip812.click"
}
