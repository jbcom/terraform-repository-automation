module "module_variables" {
  source = "../terraform-remote-module-variables"

  repository_name = "${var.repository_owner}/terraform-${var.module_name}"
  repository_tag  = var.module_version
}

locals {
  module_data = module.module_variables

  defaults_data  = local.module_data["defaults"]
  query_data     = local.module_data["query"]
  variables_data = local.module_data["variables"]

  module_dir_name = coalesce(var.module_dir_name, replace(var.category_name, "_", "-"))

  module_dir = "${var.module_root_dir}/${local.module_dir_name}"

  config_module_path = coalesce(var.config_module_path, "${local.module_dir}/${local.module_dir_name}-config")

  module_config_files = {
    (local.config_module_path) = {
      "main.tf.json" = jsonencode({
        module = {
          this = {
            source = "git@github.com:FlipsideCrypto/terraform-modules.git//external/defaults-merge"

            source_map = "$${var.config}"

            defaults_file_path = "$${path.module}/files/defaults.json"

            allow_empty_values = var.allow_empty_values

            log_file_name = "${var.category_name}.log"
            log_file_path = "$${path.root}/logs/defaults"
          }
        }

        output = {
          config = {
            value = "$${merge(var.config, module.this.results)}"

            description = "Configuration data"
          }
        }
      })

      "variables.tf.json" = jsonencode({
        variable = {
          config = {
            type = format("object({%s})", join(",", [
              for variable_name, variable_data in local.variables_data : "${variable_name}=optional(any)"
            ]))
            description = "Configuration data"
          }
        }
      })
    }

    "${local.config_module_path}/files" = {
      "defaults.json" = jsonencode(local.defaults_data)
    }
  }

  resources_module_path = coalesce(var.resource_module_path, "${local.module_dir}/${local.module_dir_name}-resources")

  module_resource_files = {
    (local.resources_module_path) = {
      "main.tf.json" = jsonencode({
        module = {
          this = merge({
            source = coalesce(var.module_source, "${var.repository_owner}/${trimprefix(var.module_name, "aws-")}/aws")
            }, var.module_source == null ? {
            version = var.module_version
            } : {}, {
            for variable_name, _ in local.variables_data : variable_name => "$${var.config.${variable_name}}" if !contains(keys(var.overrides), variable_name)
            }, {
            for variable_name in keys(var.caller_resources_module_extra_parameters) : variable_name => "$${var.${variable_name}}"
            }, {
            for variable_name, override_value in var.overrides : variable_name => override_value
          })
        }

        output = {
          resources = {
            value = "$${module.this}"

            description = "Resources data"
          }
        }
      })

      "variables.tf.json" = jsonencode({
        variable = merge({
          config = {
            type = format("object({%s})", join(",", [
              for variable_name, variable_data in local.variables_data : "${variable_name}=any"
            ]))
            description = "Configuration data"
          }
          }, {
          for variable_name in keys(var.caller_resources_module_extra_parameters) : variable_name => {
            type        = "any"
            description = "Extra parameter ${variable_name}"
          }
        })
      })
    }
  }
}
