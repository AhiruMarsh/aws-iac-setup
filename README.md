# aws-iac-setup

## 事前設定 (HCP Terraform連携用IAMロールの手動作成)
### 1. OIDCプロバイダ設定を追加
```bash
aws iam create-open-id-connect-provider \
    --url https://app.terraform.io \
    --client-id-list aws.workload.identity \
    --thumbprint-list ffffffffffffffffffffffffffffffffffffffff
```

### 2. OIDC連携用ロールを追加
```bash
TFC_ORG_NAME="a-marsh_net"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam create-role \
    --role-name "HCPTerraformServiceRole" \
    --assume-role-policy-document "$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/app.terraform.io"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "app.terraform.io:aud": "aws.workload.identity"
                },
                "StringLike": {
                    "app.terraform.io:sub": "organization:${TFC_ORG_NAME}:project:*:workspace:*:run_phase:*"
                }
            }
        }
    ]
}
EOF
)"
```

### 3. OIDC連携用ロールに管理者権限を付与
```bash
aws iam attach-role-policy \
    --role-name "HCPTerraformServiceRole" \
    --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"
```

## Terraform 実行
