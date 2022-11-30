variable "config" {
  type = object({
    workspace_name = string
    workspace_dir  = optional(string, "workspaces")

    root_dir               = string
    workspaces_in_root_dir = optional(bool, false)

    dependencies = optional(list(string), [])

    disable_backend                = optional(bool, false)
    backend_workspace_name         = optional(string)
    backend_bucket_name            = string
    backend_bucket_workspaces_path = string
    backend_dynamodb_table         = string
    backend_region                 = string

    terraform_version = string

    load_vendors_module = optional(bool, true)

    use_local_modules = optional(bool, false)

    clusters = optional(map(string), {})

    accounts        = optional(any, {})
    bind_to_account = optional(string, "")

    databases            = optional(list(string), [])
    bind_to_database     = optional(string, "")
    database_environment = optional(string, "")

    bind_to_context = optional(any, {})

    providers = optional(list(string), [])

    provider_overrides = optional(map(object({
      source  = string
      version = string
    })), {})

    aws_provider_ignore_tags = optional(any, {})

    provider_version_constraint = optional(string, ">=")

    secrets_kms_key_arn = optional(string, "")

    files_prefix = optional(string, "")

    extra_files = optional(map(string), {})

    vendor_secrets_dir    = optional(string, "")
    workspace_secrets_dir = optional(string, "secrets")

    docs_sections_pre  = optional(any, [])
    docs_sections_post = optional(any, [])
    docs_dir           = optional(string, ".")
    readme_name        = optional(string, "README.md")
  })
}
