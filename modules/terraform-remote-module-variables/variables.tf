variable "repository_name" {
  type = string

  description = "Repository name"
}

variable "repository_tag" {
  type = string

  description = "Repository tag"
}

variable "variable_files" {
  type = list(string)

  default = [
    "variables.tf",
  ]

  description = "Variable files to parse in the repository"
}

variable "defaults" {
  type = any

  default = {}

  description = "Defaults to apply to variables"
}

variable "overrides" {
  type = any

  default = {}

  description = "Overrides to inject into variables"
}

variable "local_module_source" {
  type = string

  default = ""

  description = "Use a local filesystem path for the module source if provided"
}

variable "parameter_generators" {
  type = any

  default = {}

  description = "Parameter generators for variables"
}

variable "map_name_to" {
  type = any

  default = {}

  description = "Map \"name\" variables(s) to a generator for dynamic naming"
}

variable "map_sanitized_name_to" {
  type = any

  default = {}

  description = "Map \"name\" variable(s) to a generator for dynamic naming sanitizing the results of the generator making the name JSON-friendly"
}

variable "log_dir" {
  type = string

  default = ""

  description = "Local log dir"
}

variable "github_token" {
  type = string

  sensitive = true

  default = ""

  description = "Passes a Github token to the script for use in fetching files from private repositories"
}
