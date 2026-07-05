# aws-iac-setup

IaCでAWSリソースを管理するためのセットアップリポジトリです。
HCP TerraformのDynamic Provider Credentialsを使用してAWSへの認証を行います。

## 構成概要

```
HCP Terraform Workspace
  └─ Dynamic Provider Credentials (OIDC)
       └─ AWS IAM Role (HCPTerraformServiceRole)
            └─ AdministratorAccess
```

管理対象リソース:
- HCP Terraform用 IAM OIDCプロバイダ / IAMロール
- GitHub Actions用 IAM OIDCプロバイダ / IAMロール

---

## セットアップ手順

### Step 1: 手動でのAWSリソース作成

> HCP TerraformがAWSへアクセスするために必要なIAMリソースを、先にAWS CLIで手動作成します。

#### 1-1. OIDCプロバイダを作成

```bash
aws iam create-open-id-connect-provider \
    --url https://app.terraform.io \
    --client-id-list aws.workload.identity \
    --thumbprint-list ffffffffffffffffffffffffffffffffffffffff
```

#### 1-2. OIDC連携用IAMロールを作成

```bash
TFC_ORG_NAME="<your-hcp-terraform-org-name>"
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

#### 1-3. IAMロールに管理者権限を付与

```bash
aws iam attach-role-policy \
    --role-name "HCPTerraformServiceRole" \
    --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"
```

#### 1-4. ロールARNを控えておく

```bash
aws iam get-role --role-name HCPTerraformServiceRole --query Role.Arn --output text
# => arn:aws:iam::<account-id>:role/HCPTerraformServiceRole
```

---

### Step 2: HCP Terraform Workspaceの設定

[HCP Terraform](https://app.terraform.io) にサインインし、以下を設定します。

#### 2-1. Workspaceを作成

1. 対象のOrganizationを開く
2. **New Workspace** → **Version control workflow** を選択
3. このリポジトリ（`aws-iac-setup`）を接続
4. Terraform Working Directory に `terraform` を指定して作成

#### 2-2. Dynamic Provider Credentials を設定

WorkspaceのSettings → **Variables** を開き、以下の**環境変数**を追加します。

| 変数名 | 値 | 区分 |
|---|---|---|
| `TFC_AWS_PROVIDER_AUTH` | `true` | Environment variable |
| `TFC_AWS_RUN_ROLE_ARN` | `arn:aws:iam::<account-id>:role/HCPTerraformServiceRole` | Environment variable |

> 参考: [HCP Terraform Dynamic Credentials - AWS](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration)

#### 2-3. Terraform変数を設定

同じくVariablesに以下の**Terraform変数**を追加します。

| 変数名 | 値の例 | 説明 |
|---|---|---|
| `tfc_organization_name` | `a-marsh_net` | HCP TerraformのOrganization名 |
| `tfc_project_name` | `*` (デフォルト) | HCP TerraformのProject名（ワイルドカード可） |
| `github_owner_name` | `AhiruMarsh` | GitHubのユーザー名またはOrg名 |
| `github_repository_name` | `*` (デフォルト) | GitHubリポジトリ名（ワイルドカード可） |

---

### Step 3: 既存リソースのTerraform管理下へのインポート

Step 1で手動作成したリソースをTerraform stateに取り込みます。

#### 3-1. `is_execute_import = true` を設定してPlanを実行

WorkspaceのVariablesに以下のTerraform変数を**一時的に**追加します。

| 変数名 | 値 |
|---|---|
| `is_execute_import` | `true` |

HCP Terraform上で **New Run → Plan and Apply** を実行します。
Import blockにより、既存のOIDCプロバイダとIAMロールがstateに取り込まれます。

#### 3-2. インポート後は変数を削除

インポートが完了したら `is_execute_import` 変数を削除（またはfalseに設定）します。
以降のRunでは通常のplan/applyが動作します。

---

### Step 4: 通常運用

セットアップ完了後は、`terraform/` 配下のファイルを変更してPRを作成するだけで、
HCP TerraformがSpeculative Planを実行してレビューできます。

- **PRマージ** → HCP Terraformが自動でApplyを実行
- **手動実行** → HCP TerraformのUI上で **New Run** を実行

---

## ローカルでの開発

ローカルから実行する場合はAWS認証情報が必要です（Dynamic Credentialsはローカル非対応）。

```bash
cd terraform
terraform init
terraform plan -var="tfc_organization_name=<org>" -var="github_owner_name=<owner>"
```
