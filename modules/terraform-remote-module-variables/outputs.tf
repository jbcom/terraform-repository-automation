output "variables" {
  value = local.variables_data

  description = "Variables data from the remote repository"
}

output "defaults" {
  value = local.defaults_data

  description = "Defaults data"
}

output "query" {
  value = local.query

  description = "Query data"
}