# Terraform全体の設定（プロバイダとstate管理）

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # stateはS3で管理する（CI/CDのGitHub Actionsからも同じstateを参照・更新する）
  # バケット自体は infra/bootstrap で初回に作成する
  backend "s3" {
    bucket       = "todo-fullstack-tfstate-201302613838"
    key          = "todo-fullstack/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

# リソース名の一部に使うAWSアカウントID
data "aws_caller_identity" "current" {}
