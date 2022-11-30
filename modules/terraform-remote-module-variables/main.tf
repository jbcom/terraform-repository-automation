locals {
  query = {
    repository_name       = var.repository_name
    repository_tag        = var.repository_tag
    variable_files        = jsonencode(var.variable_files)
    defaults              = jsonencode(var.defaults)
    overrides             = jsonencode(var.overrides)
    local_module_source   = var.local_module_source
    parameter_generators  = jsonencode(var.parameter_generators)
    map_name_to           = jsonencode(var.map_name_to)
    map_sanitized_name_to = jsonencode(var.map_sanitized_name_to)
  }
}

data "external" "this" {
  program = ["python", "${path.module}/bin/main.py"]

  query = merge(local.query, {
    github_token = var.github_token
    log_file     = "${path.root}/logs/${var.repository_name}/${var.repository_tag}.log"
  })
}

locals {
  variables_data = jsondecode(base64decode(data.external.this.result["merged_map"]))

  defaults_data = {
    for variable_name, variable_data in local.variables_data : variable_name => variable_data["default_value"]
  }
}