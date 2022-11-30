module "terraform_workspace" {
  for_each = try(nonsensitive(var.workspaces), var.workspaces)

  source = "../terraform-workspace"

  config = merge(each.value, {
    workspace_name = lookup(each.value, "workspace_name", element(split("/", each.key), length(split("/", each.key)) - 1))
  })
}

locals {
  workspaces = merge({
    for workspace_name, workspace_data in module.terraform_workspace : workspace_name => merge(var.workspaces[workspace_name], workspace_data["config"])
  }, var.extra_workflow_workspaces)

  workflow_base_config = merge(var.workflow_config, {
    workspaces = local.workspaces
  })

  triggers_autopopulate = lookup(local.workflow_base_config, "triggers_autopopulate", true)

  workspace_merge_records = distinct(compact(flatten([
    for _, workspace_data in local.workspaces : concat([
      try(workspace_data["bind_to_context"]["merge_record"], ""),
    ], try(workspace_data["bind_to_context"]["merge_records"], []))
  ])))

  triggers = distinct(flatten(concat(lookup(local.workflow_base_config, "triggers", []), local.workspace_merge_records)))

  workflow_config = merge(local.workflow_base_config, {
    triggers_autopopulate = local.triggers_autopopulate

    triggers = local.triggers
  })
}

module "terraform_workflows" {
  source = "../terraform-workflow"

  workflow_name = var.workflow_name

  config = local.workflow_config
}

locals {
  pipeline_files = flatten(concat(module.terraform_workflows.files, [
    for _, workspace_files in module.terraform_workspace : workspace_files["files"]
    ], var.bootstrap_github_actions ? [
    {
      ".github" = {
        for file_name in fileset("${path.module}/files", "*") : file_name => file("${path.module}/files/${file_name}")
      }
    }
  ] : []))
}