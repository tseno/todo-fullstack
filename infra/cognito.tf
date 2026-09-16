# Cognito User Pool（認証基盤）
# すでにapply済みのリソース。名前などを変えると再作成になるため変更しない

resource "aws_cognito_user_pool" "main" {
  name = "todo-fullstack-user-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "todo-fullstack-201302613838"
  user_pool_id = aws_cognito_user_pool.main.id

  managed_login_version = "1"
}

# Hosted UIのログイン/ログアウト後の遷移先（リダイレクト先URLの許可リスト）
# localhost（開発用）とCloudFront（本番用）の両方を許可する
resource "aws_cognito_user_pool_client" "main" {
  name         = "todo-fullstack-user-pool-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret                      = false
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true

  callback_urls = [
    "http://localhost:3000",
    "https://${aws_cloudfront_distribution.frontend.domain_name}",
  ]

  # Hosted UIの /logout には logout_uri パラメータでここに登録したURLを渡す
  logout_urls = [
    "http://localhost:3000",
    "https://${aws_cloudfront_distribution.frontend.domain_name}",
  ]
}
