output "workspace_name" {
  value = local.workspace_name

  description = "Terraform workspace name"
}

output "files" {
  value = local.workspace_files

  description = "Workspace files"
}

output "config" {
  value = merge(var.config, local.template_variables, {
    workspace_dir = local.workspace_dir
  })

  description = "Workspace config"
}
