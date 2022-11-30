locals {
  sops_yaml = yamlencode({
    creation_rules = [
      {
        path_regex = "${var.secrets_dir}/.*"

        kms = var.kms_key_arn
      }
    ]
  })

  docs = {
    title = var.docs_title != "" ? var.docs_title : basename(var.secrets_dir)

    sections = concat(var.docs_sections_pre, [
      {
        title       = "secrets"
        description = <<EOT
This directory is setup to use SOPS to store secrets in a subdirectory, [${var.secrets_dir}](./${var.secrets_dir}).

[Mozilla SOPS](https://github.com/mozilla/sops) is is an editor of encrypted files that supports YAML, JSON, ENV, INI and BINARY formats.

You can follow the instructions on the SOPS website for [downloading](https://github.com/mozilla/sops#stable-release) the binary or you can on MacOS or Linux (With LinuxBrew) use the SOPS [Homebrew Formulae](https://formulae.brew.sh/formula/sops).

The [.sops.yaml](.sops.yaml) configuration file, managed by Terraform, tells SOPS what KMS key to use.

For this directory the KMS key used is: **${var.kms_key_arn}**.

This file will be read when SOPS is called within the directory, meaning you can call SOPS from a Github Action safely, same as you would locally.

Mozilla maintains its own set of [examples](https://github.com/mozilla/sops#examples) which cover all the possible scenarios for encrypting and decrypting secrets.
EOT
      }
    ], var.docs_sections_post)
  }
}

module "readme-doc" {
  source = "github.com/jbcom/terraform-github-markdown//modules/markdown-document"

  config = local.docs
}

locals {
  files = [
    {
      (var.base_dir) = {
        ".sops.yaml" = local.sops_yaml
      }

      "${var.base_dir}/${var.docs_dir}" = {
        (coalesce(var.readme_name, "${basename(var.secrets_dir)}.md")) = module.readme-doc.document
      }

      "${var.base_dir}/${var.secrets_dir}" = {
        "README.md" = <<EOT
# Secrets Directory

## Warning

All files (other than this README) **must** be encrypted with SOPS before committing to the Git history.

It is your responsibility as a code maintainer to ensure that this takes place.
EOT
      }
    }
  ]
}
