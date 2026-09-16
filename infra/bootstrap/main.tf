# 本体のTerraformがstateを保存するためのS3バケットを作る最小構成。
# 初回のみこのディレクトリで terraform apply する（バケットはS3バックエンド自身には作れないため）

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "todo-fullstack-tfstate-201302613838"

  tags = { Name = "todo-fullstack-tfstate" }
}

# 誤って消したstateを復旧できるようバージョニングを有効にする
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
