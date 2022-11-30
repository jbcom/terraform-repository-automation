resource "tfe_organization" "this" {
  name  = var.name
  email = var.email_address
}

resource "tfe_oauth_client" "github" {
  name             = "github"
  organization     = tfe_organization.this.name
  api_url          = "https://api.github.com"
  http_url         = "https://github.com"
  oauth_token      = var.github_token
  service_provider = "github"
}