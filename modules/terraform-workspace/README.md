# terraform-workspace

Configures a Terraform workspace

## Parameters

* workflow: Whether to generate the Github Actions terraform workflow for the repository automatically.
* modules: Whether to treat the repository as a Terraform repository of modules, meaning no active workspaces,
  just stored Terraform code for access by other repositories.
* provider: Whether to treat the repository as a Terraform provider repository with a standard Golang build
  and release pipeline. See 'terraform-provider-googleworkspace' for an example.
* root_dir: The root directory of Terraform modules and workspaces in the repository. Defaults to 'terraform'.
* gitignore: Whether to manage the gitignore file for the Terraform generated directories in the repository.
* workspaces: A map of all Terraform workspaces by name and a list of workspaces they depend on in Github
  Actions.
* workspace_files: Whether to generate the Terraform workspace files for the backend.
* pin_versions: Whether to pin versions for the automatically generated version files. Defaults to true for production environments, false otherwise.
  False does not mean no pinning, it simply pins to the minimum supported version for each provider.
* manage_context: Whether to generate a local variable called context containing environment and department specific data.
  For information on the context object please see the internal-organization repository.
* eks_clusters: EKS clusters to automatically provision for the GitHub repository's Terraform workspaces. Defaults to
  the clusters specified globally for the backend configuration if any.