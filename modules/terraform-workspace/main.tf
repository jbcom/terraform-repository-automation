locals {
  workspace_name = var.config.workspace_name

  region = var.config.backend_region

  defaults_dir = "${path.module}/defaults"

  files_prefix = var.config.files_prefix != "" ? "${var.config.files_prefix}-" : ""
  ignore_files_prefix = [
    ".gitignore",
    "Makefile",
  ]

  provider_config = merge(jsondecode(file("${local.defaults_dir}/providers.json")), var.config.provider_overrides)

  default_providers = distinct(concat(keys(var.config.provider_overrides), [
    "aws",
    "awsutils",
    "assert",
    "sops",
    "utils",
    ], var.config.clusters != {} ? [
    "kubectl",
    "kubernetes",
    "helm",
    ] : [], var.config.bind_to_database != "" ? [
    "postgresql"
    ] : [], length(var.config.databases) > 0 ? [
    "postgresql"
  ] : []))

  providers = distinct(concat(local.default_providers, var.config.providers))
}

data "assert_test" "provider-definition-exists" {
  for_each = toset(local.providers)

  test  = lookup(local.provider_config, each.key, null) != null
  throw = "provider ${each.key} has no defaults - Please provide a definition in the provider overrides"
}

locals {
  root_dir            = var.config["root_dir"]
  workspaces_dir_name = var.config["workspaces_in_root_dir"] ? "" : var.config["workspace_dir"]
  workspaces_path_components = compact([
    local.root_dir,
    local.workspaces_dir_name,
  ])

  workspaces_dir = join("/", local.workspaces_path_components)

  rel_path_depth = length(split("/", local.workspaces_dir))
  rel_path_to_root = join("/", [
    for i in range(0, local.rel_path_depth) : ".."
  ])

  use_local_modules = var.config.use_local_modules

  modules_source = local.use_local_modules ? "${local.rel_path_to_root}/modules" : "git@github.com:FlipsideCrypto/terraform-modules.git/"

  terraform_semver_segments = split(".", var.config["terraform_version"])
  terraform_major_version   = local.terraform_semver_segments[0]
  terraform_minor_version   = length(local.terraform_semver_segments) > 1 ? local.terraform_semver_segments[1] : "0"
  terraform_major_minor_version = join(".", [
    local.terraform_major_version,
    local.terraform_minor_version,
  ])

  template_variables = merge(var.config, {
    workspace_name                = var.config.workspace_name
    provider_config               = local.provider_config
    providers                     = local.providers
    backend_region                = local.region
    backend_workspace_name        = coalesce(var.config.backend_workspace_name, local.workspace_name)
    secrets_dir                   = var.config.vendor_secrets_dir != "" ? var.config.vendor_secrets_dir : ""
    use_local_secrets             = var.config.vendor_secrets_dir != ""
    terraform_major_minor_version = local.terraform_major_minor_version

    rel_to_root = local.rel_path_to_root
  })

  backend_required_providers_tf_json = jsonencode({
    terraform = {
      required_providers = {
        for provider_name in local.providers : provider_name => {
          source  = local.provider_config[provider_name]["source"]
          version = format("%s %s", var.config["provider_version_constraint"], local.provider_config[provider_name]["version"])
        }
      }
    }
  })

  provider_tf_json_dir = "${path.module}/templates/provider.tf.json"

  base_aws_provider_tf_json = merge({
    region = var.config.backend_region
    }, var.config.aws_provider_ignore_tags != {} ? {
    ignore_tags = var.config.aws_provider_ignore_tags
  } : {})

  parameters_aws_provider_tf_json = merge(local.base_aws_provider_tf_json, {
    alias = "parameters"
  })

  clusters_aws_provider_tf_json = [
    for cluster_name, execution_role_arn in var.config["clusters"] : merge(local.base_aws_provider_tf_json, {
      alias = "cluster_${cluster_name}"
      }, execution_role_arn != "" ? {
      assume_role = {
        role_arn = execution_role_arn
      }
    } : {})
  ]

  root_aws_provider_tf_json = merge(local.base_aws_provider_tf_json, var.config["bind_to_account"] != "" ? {
    assume_role = {
      role_arn = var.config["bind_to_account"]
    }
  } : {})

  accounts_aws_provider_tf_json = flatten(concat([
    local.root_aws_provider_tf_json,
    local.parameters_aws_provider_tf_json,
    local.clusters_aws_provider_tf_json,
    ], [
    for account_alias, execution_role_arn in var.config["accounts"] : merge(local.base_aws_provider_tf_json, {
      alias = account_alias

      assume_role = {
        role_arn = execution_role_arn
      }
    })
  ]))

  aws_provider_tf_json = {
    aws = local.accounts_aws_provider_tf_json
    awsutils = [
      for provider_tf_json in local.accounts_aws_provider_tf_json : {
        for k, v in provider_tf_json : k => v if k != "ignore_tags"
      }
    ]
  }

  clusters_tf_json = [
    for cluster_name, execution_role_arn in var.config["clusters"] : templatefile("${local.provider_tf_json_dir}/cluster.json", {
      cluster_name = cluster_name
    })
  ]

  postgresql_provider_tf_json_file = "${local.provider_tf_json_dir}/postgresql.json"

  root_postgresql_provider_tf_json = var.config["bind_to_database"] != "" ? jsondecode(templatefile(local.postgresql_provider_tf_json_file, {
    database_name = var.config["bind_to_database"]
  })) : {}

  databases_postgresql_provider_tf_json_unfiltered = concat([
    local.root_postgresql_provider_tf_json,
    ], [
    for database_name in var.config["databases"] : merge(jsondecode(templatefile(local.postgresql_provider_tf_json_file, {
      database_name = database_name
      })), {
      alias = database_name
    })
  ])

  databases_postgresql_provider_tf_json = [
    for database_block in local.databases_postgresql_provider_tf_json_unfiltered : database_block if database_block != {}
  ]

  database_parameters_tf_json = templatefile("${path.module}/templates/database_parameters.tf.json", {
    database_environment = var.config["database_environment"] != "" ? var.config["database_environment"] : "$${local.environment}"
  })

  postgresql_provider_tf_json = length(var.config["databases"]) > 0 ? {
    postgresql = local.databases_postgresql_provider_tf_json
  } : {}

  providers_with_parameters = {
    for provider_name in local.providers : provider_name => local.provider_config[provider_name]["parameters"] if try(local.provider_config[provider_name]["parameters"], null) != null
  }

  vendors_provider_tf_json_unfiltered = {
    for provider_name, provider_parameters in local.providers_with_parameters : provider_name =>
    merge(lookup(provider_parameters, "static", {}), {
      for k, v in lookup(provider_parameters, "vendor", {}) : k => "$${local.vendors_data.${v}}"
    })
  }

  vendors_provider_tf_json = {
    for provider_name, provider_parameters in local.vendors_provider_tf_json_unfiltered : provider_name => provider_parameters != {} ? [
      provider_parameters,
    ] : []
  }

  providers_tf_json = jsonencode({
    provider = merge(local.aws_provider_tf_json, local.postgresql_provider_tf_json, local.vendors_provider_tf_json)
  })

  default_context_parameters = yamldecode(file("${local.defaults_dir}/context.yaml"))

  context_object_parameters = {
    for k, v in var.config["bind_to_context"] : k => v if contains(keys(local.default_context_parameters), k)
  }

  context_config_object_parameters = {
    for k, v in var.config["bind_to_context"] : k => v if !contains(keys(local.default_context_parameters), k)
  }

  context_state_key  = lookup(var.config["bind_to_context"], "state_key", "context")
  context_object_key = lookup(var.config["bind_to_context"], "object_key", local.context_state_key)

  context_tf_json = jsonencode({
    module = {
      context = merge({
        source      = "git@github.com:FlipsideCrypto/terraform-modules.git//utils/context"
        config      = local.context_config_object_parameters
        rel_to_root = "$${local.rel_to_root}"
        }, {
        for k, _ in local.context_object_parameters : k => "$${local.${k}}"
        }, {
        stage = lookup(local.context_object_parameters, "stage", "$${local.region}")
        tags = {
          for k, v in merge(lookup(local.context_object_parameters, "tags", {}), {
            Terraform    = "terraform"
            Owner        = "DevOps"
            Organization = "FlipsideCrypto"
          }) : k => v if k != "Name"
        }
      })
    }

    locals = {
      (local.context_object_key) = "$${module.context.context}"
    }
  })

  locals_tf_json = jsonencode({
    locals = merge({
      use_local_secrets   = var.config.vendor_secrets_dir != ""
      root_dir            = local.root_dir
      workspaces_dir      = local.workspaces_dir
      workspaces_dir_name = local.workspaces_dir_name
      workspace_dir       = local.workspace_dir
    }, local.context_object_parameters)
  })

  tf_json_files_data = flatten(concat([
    templatefile("${path.module}/templates/backend.tf.json", local.template_variables),
    local.backend_required_providers_tf_json,
    local.providers_tf_json,
    local.locals_tf_json,
    ], var.config["load_vendors_module"] ? [
    templatefile("${path.module}/templates/providers.tf.json", local.template_variables),
    ] : [], var.config["bind_to_context"] != {} ? [
    local.context_tf_json,
    ] : [], length(var.config["databases"]) > 0 ? [
    local.database_parameters_tf_json,
  ] : [], local.clusters_tf_json))
}

data "assert_test" "tf-json-is-valid" {
  count = length(local.tf_json_files_data)

  test  = try(jsondecode(local.tf_json_files_data[count.index]), null) != null
  throw = "JSON file data invalid:\n\n${local.tf_json_files_data[count.index]}"
}

data "utils_deep_merge_json" "tf-json-merge" {
  input = local.tf_json_files_data

  append_list = true

  deep_copy_list = true

  depends_on = [
    data.assert_test.tf-json-is-valid,
  ]
}

locals {
  docs_sections = concat(var.config.docs_sections_pre, length(var.config.dependencies) > 0 ? [
    {
      title       = "Terraform Workspace Dependencies"
      description = <<EOT
This Terraform workspace has dependencies that need to be run ahead of it.
This is configured automatically in the Terraform workflow for this workspace but will need to be accounted for if running manually.

They are:
%{for dependency in var.config.dependencies~}
* ${dependency}
%{endfor~}
EOT
    }
  ] : [], var.config.docs_sections_post)

  workspace_files_data = merge({
    "config.tf.json" = data.utils_deep_merge_json.tf-json-merge.output
    ".tool-versions" = "terraform ${var.config["terraform_version"]}"
    ".gitignore"     = file("${path.module}/files/terraform.gitignore")
  }, var.config["extra_files"])

  workspace_dir = "${local.workspaces_dir}/${local.workspace_name}"

  terraform_workspace_files = {
    (local.workspace_dir) = {
      for file_name, file_contents in local.workspace_files_data : (contains(local.ignore_files_prefix, file_name) ? file_name : "${local.files_prefix}${file_name}") => replace(replace(file_contents, "$${MODULES_SOURCE}", local.modules_source), "$${REL_TO_ROOT}", local.rel_path_to_root) if file_contents != ""
    }
  }
}

module "readme_doc" {
  count = var.config.secrets_kms_key_arn == "" ? 1 : 0

  source = "../../markdown/markdown-document"

  config = {
    title = "Terraform ${local.workspace_name} Workspace"

    sections = local.docs_sections
  }
}

module "kms_sops_directory" {
  count = var.config.secrets_kms_key_arn != "" ? 1 : 0

  source = "../terraform-secrets"

  kms_key_arn = var.config.secrets_kms_key_arn

  base_dir    = local.workspace_dir
  secrets_dir = var.config.workspace_secrets_dir

  docs_dir          = var.config.docs_dir
  docs_title        = "Terraform ${local.workspace_name} Workspace"
  docs_sections_pre = local.docs_sections
  readme_name       = var.config.readme_name
}

locals {
  workspace_files = flatten(concat([
    local.terraform_workspace_files,
    ], var.config.secrets_kms_key_arn == "" ? [{
      "${local.workspace_dir}/${var.config.docs_dir}" = {
        (var.config.readme_name) = module.readme_doc.0.document
      }
    }
  ] : module.kms_sops_directory.0.files))
}

