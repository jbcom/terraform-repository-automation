variable "workspaces" {
  type = any

  description = "Workspaces configuration"
}

variable "workflow_name" {
  type = string

  description = "Workflow name"
}

variable "workflow_config" {
  type = any

  default = {}

  description = "Workflow configuration"
}

variable "extra_workflow_workspaces" {
  type = any

  default = {}

  description = "Extra unmanaged workflow workspaces"
}

variable "bootstrap_github_actions" {
  type = bool

  default = false

  description = "Whether to bootstrap Github Actions with this pipeline, setting up the necessary configuration files"
}
