variable "kms_key_arn" {
  type = string

  description = "KMS key ARN"
}

variable "base_dir" {
  type = string

  default = "."

  description = "Base directory"
}

variable "secrets_dir" {
  type = string

  default = "secrets"

  description = "Secrets directory"
}

variable "docs_title" {
  type = string

  default = ""

  description = "Title for the documentation - Defaults to the secrets directory name"
}

variable "docs_sections_pre" {
  type = any

  default = []

  description = "Extra sections to include in the docs before the secrets documentation"
}

variable "docs_sections_post" {
  type = any

  default = []

  description = "Extra sections to include in the docs after the secrets documentation"
}

variable "docs_dir" {
  type = string

  default = "docs"

  description = "Documentation directory"
}

variable "readme_name" {
  type = string

  default = null

  description = "Readme file name"
}
