<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.0 |
| <a name="requirement_tfe"></a> [tfe](#requirement\_tfe) | >=0.31.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_tfe"></a> [tfe](#provider\_tfe) | >=0.31.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [tfe_oauth_client.github](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/oauth_client) | resource |
| [tfe_organization.this](https://registry.terraform.io/providers/hashicorp/tfe/latest/docs/resources/organization) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_github_token"></a> [github\_token](#input\_github\_token) | GitHub token | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->