output "variables" {
  value = local.module_data["variables"]

  description = "Variables data"
}

output "files" {
  value = concat(var.generate_config_module ? [
    local.module_config_files,
    ] : [], var.generate_resource_module ? [
    local.module_resource_files,
  ] : [])

  description = "Files data"
}

locals {
  caller_targets = {
    for target in var.generate_callers_for : lower(replace(target, "/\\W|-|\\s/", "_")) => target
  }

  sanitized_caller_targets = keys(local.caller_targets)

  category_module_name = lower(replace(var.category_name, "/\\W|-|\\s/", "_"))
}

output "callers" {
  value = {
    "${local.category_module_name}_config.tf.json" = jsonencode({
      data = {
        terraform_remote_state = {
          config_source_data = {
            backend = "s3"

            config = {
              bucket = "flipside-crypto-internal-tooling"
              key    = var.caller_target_config_state_path
              region = "us-east-1"
            }
          }
        }
      }

      locals = {
        config_source_data = "$${data.terraform_remote_state.config_source_data.outputs.${var.caller_target_config_output_key}}"
      }

      module = {
        for sanitized_caller_target, caller_target in local.caller_targets : "config_${sanitized_caller_target}" => {
          source = "${var.rel_to_root_substitution_pattern}/${local.config_module_path}"

          config = "$${local.config_source_data[\"${caller_target}\"]}"
        }
      }
    })

    "${local.category_module_name}.tf.json" = jsonencode({
      locals = {
        extra_parameters = {
          for sanitized_caller_target, caller_target in local.caller_targets : caller_target => {
            for k, v in var.caller_resources_module_extra_parameters : k => replace(replace(replace(replace(v, "|CONFIG|", "module.config_|SANITIZED_CALLER_TARGET|.config"), "|CALLER_TARGET|", caller_target), "|SANITIZED_CALLER_TARGET|", sanitized_caller_target), "|OUTPUT_KEY|", var.caller_target_config_output_key)
          }
        }
      }

      module = {
        for sanitized_caller_target, caller_target in local.caller_targets : sanitized_caller_target => merge({
          source = "${var.rel_to_root_substitution_pattern}/${local.resources_module_path}"

          config = "$${module.config_${sanitized_caller_target}.config}"
          }, {
          for k, v in var.caller_resources_module_extra_parameters : k => replace(replace(replace(replace(v, "|CONFIG|", "module.config_|SANITIZED_CALLER_TARGET|.config"), "|CALLER_TARGET|", caller_target), "|SANITIZED_CALLER_TARGET|", sanitized_caller_target), "|OUTPUT_KEY|", var.caller_target_config_output_key)
        })
      }
    })

    "main.tf.json" = jsonencode({
      locals = {
        resources = {
          for sanitized_caller_target, caller_target in local.caller_targets : caller_target => "$${module.${sanitized_caller_target}.resources}"
        }
      }
    })

    "outputs.tf.json" = jsonencode({
      output = {
        resources = {
          value       = "$${local.resources}"
          sensitive   = true
          description = "Resource data"
        }
      }
    })
  }

  description = "Callers to use to generate the configuration and pass it on to resources"
}
