locals {
  oidc_gha_url       = "token.actions.githubusercontent.com"
  oidc_gha_client_id = "sts.amazonaws.com"
}

data "tls_certificate" "actions" {
  url = "https://${local.oidc_gha_url}"
}

resource "aws_iam_openid_connect_provider" "actions" {
  url = "https://${local.oidc_gha_url}"

  client_id_list  = [local.oidc_gha_client_id]
  thumbprint_list = [data.tls_certificate.actions.certificates.0.sha1_fingerprint]
}

data "aws_iam_policy_document" "actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_gha_url}:aud"
      values   = [local.oidc_gha_client_id]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_gha_url}:sub"
      values = [
        "repo:${var.github_owner_name}/${var.github_repository_name}"
      ]
    }
  }
}

resource "aws_iam_role" "actions" {
  name               = "GitHubActionsServiceRole"
  assume_role_policy = data.aws_iam_policy_document.actions_assume_role.json
}

resource "aws_iam_role_policy_attachment" "actions" {
  role       = aws_iam_role.actions.name
  policy_arn = data.aws_iam_policy.administrator_access.arn
}
