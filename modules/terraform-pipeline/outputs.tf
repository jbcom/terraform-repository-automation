output "files" {
  value = local.pipeline_files

  description = "Pipeline files"
}

output "pipeline" {
  value = {
    workspace_config = {
      for workspace_name, workspace_data in module.terraform_workspace : workspace_name => workspace_data["config"]
    }

    workflow_config = module.terraform_workflows.config

    workflow_file_names = module.terraform_workflows.workflow_file_names

    workflow_name = module.terraform_workflows.workflow_name

    workspaces = local.workspaces
  }

  description = <<EOT
Data for the Terraform pipeline

Includes naming for the workflow and for its GitHub Actions workflow file name.

Also includes configuration for both the workflow and all workspaces, as well as the buildouts for all workspaces.
EOT
}