variable "category_name" {
  type = string

  description = "Category name for the CloudPosse module"
}

variable "module_name" {
  type = string

  description = "CloudPosse ECS module to build out"
}

variable "module_version" {
  type = string

  description = "CloudPosse ECS module version"
}

variable "module_source" {
  type = string

  default = null

  description = "Override for the module source"
}

variable "module_root_dir" {
  type = string

  default = "modules"

  description = "Modules root directory"
}

variable "module_dir_name" {
  type = string

  default = null

  description = "Module directory name, defaults to the category name with dashes instead of underscores"
}

variable "config_module_path" {
  type = string

  default = null

  description = "Isolated path for the configuration module"
}

variable "resource_module_path" {
  type = string

  default = null

  description = "Isolated path for the resource module"
}

variable "generate_config_module" {
  type = bool

  default = true

  description = "Whether to generate the config module"
}

variable "generate_resource_module" {
  type = bool

  default = true

  description = "Whether to generate the resource module"
}

variable "allow_empty_values" {
  type = bool

  default = false

  description = "Whether to allow empty values or fill them with their defaults, if any"
}

variable "overrides" {
  type = any

  default = {}

  description = "Overrides for the passthrough"
}

variable "repository_owner" {
  type = string

  default = "cloudposse"

  description = "Repository owner"
}

variable "generate_callers_for" {
  type = list(string)

  default = []

  description = "Generate a config and infrastructure caller file for each of these"
}

variable "caller_target_config_state_path" {
  type = string

  default = ""

  description = "Terraform state path to query for configuration for each caller target"
}

variable "caller_target_config_output_key" {
  type = string

  default = ""

  description = "Output key of the Terraform state path to query for configuration for each caller target"
}

variable "caller_resources_module_extra_parameters" {
  type = any

  default = {}

  description = "Extra parameters to pass through to resources module in the caller"
}

variable "rel_to_root_substitution_pattern" {
  type = string

  default = "$${REL_TO_ROOT}"

  description = "Substitution pattern for the rel_to_root local when called in a Terraform workspace"
}
