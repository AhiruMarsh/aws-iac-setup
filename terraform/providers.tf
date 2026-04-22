provider "aws" {
  region              = "ap-northeast-1"
  shared_config_files = try([var.tfc_aws_dynamic_credentials.default.shared_config_file], null)

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      GitRepos  = "https://github.com/AhiruMarsh/aws-iac-setup"
    }
  }
}
