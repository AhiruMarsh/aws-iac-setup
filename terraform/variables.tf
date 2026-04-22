# TFC Configuration
# https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration
variable "tfc_aws_dynamic_credentials" {
  description = "Object containing AWS dynamic credentials configuration"
  type = object({
    default = object({
      shared_config_file = string
    })
    aliases = map(object({
      shared_config_file = string
    }))
  })
  default = null
}

variable "is_execute_import" {
  description = "Is true, import HCPTerraformServiceRole"
  type        = bool
  default     = false
}

variable "tfc_organization_name" {
  description = "HCP Terraform organization name"
  type        = string
}

variable "tfc_project_name" {
  description = "HCP Terraform project name"
  type        = string
  default     = "*"
}

variable "github_owner_name" {
  description = "GitHub owner name"
  type        = string
}

variable "github_repository_name" {
  description = "GitHub repository name"
  type        = string
  default     = "*"
}

