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

resource "aws_cognito_user_pool" "main" {
  name = "todo-fullstack-user-pool"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_domain" "main" {
  domain = "todo-fullstack-201302613838"
  user_pool_id = aws_cognito_user_pool.main.id
  managed_login_version = "1"
}

resource "aws_cognito_user_pool_client" "main" {
  name = "todo-fullstack-user-pool-client"
  user_pool_id = aws_cognito_user_pool.main.id
  generate_secret = false
  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["openid", "email", "profile"]
  callback_urls = ["http://localhost:3000"]
  supported_identity_providers = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.main.id
}

output "hosted_ui_domain" {
  value = "${aws_cognito_user_pool_domain.main.domain}.auth.ap-northeast-1.amazoncognito.com"
}