locals {
  oidc_tfc_url       = "app.terraform.io"
  oidc_tfc_client_id = "aws.workload.identity"
}

data "aws_iam_openid_connect_provider" "tfc" {
  count = var.is_execute_import ? 1 : 0
  url   = "https://${local.oidc_tfc_url}"
}

import {
  for_each = var.is_execute_import ? [1] : []

  to = aws_iam_openid_connect_provider.tfc
  identity = {
    "arn" = data.aws_iam_openid_connect_provider.tfc[0].arn
  }
}

data "tls_certificate" "tfc" {
  url = "https://${local.oidc_tfc_url}"
}

resource "aws_iam_openid_connect_provider" "tfc" {
  url = "https://${local.oidc_tfc_url}"

  thumbprint_list = [data.tls_certificate.actions.certificates.0.sha1_fingerprint]
  client_id_list  = [local.oidc_tfc_client_id]
}

data "aws_iam_policy_document" "tfc_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.tfc.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_tfc_url}:aud"
      values   = [local.oidc_tfc_client_id]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_tfc_url}:sub"
      values = [
        "organization:${var.tfc_organization_name}:project:${var.tfc_project_name}:workspace:*:run_phase:*"
      ]
    }
  }
}

data "aws_iam_role" "tfc" {
  count = var.is_execute_import ? 1 : 0
  name  = "HCPTerraformServiceRole"
}

import {
  for_each = var.is_execute_import ? [1] : []

  to = aws_iam_role.tfc
  identity = {
    name = data.aws_iam_role.tfc[0].name
  }
}

resource "aws_iam_role" "tfc" {
  name               = "HCPTerraformServiceRole"
  assume_role_policy = data.aws_iam_policy_document.tfc_assume_role.json
}

import {
  for_each = var.is_execute_import ? [1] : []

  to = aws_iam_role_policy_attachment.tfc
  identity = {
    role       = data.aws_iam_role.tfc[0].name
    policy_arn = data.aws_iam_policy.administrator_access.arn
  }
}

resource "aws_iam_role_policy_attachment" "tfc" {
  role       = aws_iam_role.tfc.name
  policy_arn = data.aws_iam_policy.administrator_access.arn
}
