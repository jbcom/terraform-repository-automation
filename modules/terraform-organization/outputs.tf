output "organization" {
  value = tfe_organization.this

  description = "Organization data"
}

output "github_oauth_client" {
  value = tfe_oauth_client.github

  description = "Github oauth client data"
}