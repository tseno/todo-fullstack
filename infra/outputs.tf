# terraform output で参照する値

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.main.id
}

output "hosted_ui_domain" {
  value = "${aws_cognito_user_pool_domain.main.domain}.auth.ap-northeast-1.amazoncognito.com"
}

output "cloudfront_domain" {
  value = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.backend.name
}

output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}
