variable "name" {
  type = string

  description = "Organization name"
}

variable "email_address" {
  type = string

  description = "Email address"
}

variable "github_token" {
  type = string

  sensitive = true

  description = "GitHub token"
}