output "workflow_name" {
  value = var.workflow_name

  description = "Workflow name for chaining"
}

output "workflow_file_names" {
  value = keys(local.workflow_yaml_files)

  description = "Workflow file names for chaining"
}

output "files" {
  value = local.workflow_files

  description = "Terraform workflow repository files"
}

output "config" {
  value = local.workflow_config

  description = "Terraform workflow config"
}