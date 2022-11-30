variable "workflow_name" {
  type = string

  default = "terraform"

  description = "Workflow name"
}

variable "config" {
  type = object({
    trigger_dir                    = optional(string, "")
    trigger_dirs                   = optional(list(string), [])
    trigger_dirs_autopopulate      = optional(bool, true)
    triggers                       = optional(list(string), [])
    triggers_autopopulate          = optional(bool, true)
    trigger_branches               = optional(list(string), [])
    trigger_tags                   = optional(list(string), [])
    trigger_branches_autopopulate  = optional(bool, true)
    trigger_on_workflow_completion = optional(list(string), [])

    publish_release         = optional(bool, false)
    release_tag_prefix      = optional(string, "v")
    pipeline_release_branch = optional(string, "main")

    concurrency_group = optional(string, "terraform")

    workspaces = optional(map(object({
      workspace_name    = string
      workspace_dir     = string
      workspace_branch  = string
      job_name          = string
      dependencies      = optional(list(string), [])
      terraform_version = string
    })), {})

    run_schedules = optional(list(string), [])

    call_workflows_before = optional(list(string), [])
    call_workflows_after  = optional(list(string), [])

    no_automatic_triggers   = optional(bool, false)
    trigger_on_call         = optional(bool, false)
    trigger_on_dispatch     = optional(bool, true)
    trigger_on_push         = optional(bool, false)
    trigger_on_pull_request = optional(bool, false)
    trigger_on_release      = optional(bool, false)
  })

  description = <<EOT
Configuration for a Terraform workflow.

Please see README.md for a description of parameters.
EOT
}