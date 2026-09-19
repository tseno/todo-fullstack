# フロントエンドの配信: S3 + CloudFront
# CloudFrontは以下の2役を担う:
# - /*      → S3のNext.js静的エクスポート（HTTPS配信）
# - /api/*  → ALBへ転送（バックエンドAPI）
# ブラウザからは常にCloudFrontのHTTPS URLだけを見るため、混在コンテンツ問題も発生しない

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${data.aws_caller_identity.current.account_id}"

  # デプロイしたファイルが残っていても terraform destroy できるようにする
  force_destroy = true

  tags = { Name = "${var.project_name}-frontend" }
}

# 公開はCloudFront経由のみに限定する
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# S3への直接アクセスではなく、署名付きリクエスト（OAC）でCloudFrontに読ませる
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          # このCloudFrontディストリビューションからのアクセスだけを許可する
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
        }
      }
    }]
  })
}

# SPAのフォールバック。拡張子のないパスを index.html に書き換える。
# デフォルトビヘイビア（S3）にだけ紐づけるので、/api/* のエラーは加工されずそのまま返る
resource "aws_cloudfront_function" "spa_fallback" {
  name    = "${var.project_name}-spa-fallback"
  runtime = "cloudfront-js-2.0"
  publish = true

  code = <<-EOT
    function handler(event) {
      var uri = event.request.uri;
      var lastSegment = uri.split('/').pop();
      if (lastSegment.indexOf('.') === -1) {
        event.request.uri = '/index.html';
      }
      return event.request;
    }
  EOT
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  comment             = "${var.project_name} frontend"
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "alb-backend"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # CloudFront→ALB間は同一リージョンの内側経路でHTTP
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    # AWS管理ポリシー: CachingOptimized（静的ファイルに最適なキャッシュ設定）
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    # 未知のパスは index.html を返す（フロントエンドのルーティング用）
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_fallback.arn
    }
  }

  # /api/* はキャッシュせず、Authorizationヘッダも含めてすべてALBへ転送する
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "alb-backend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    # AWS管理ポリシー: CachingDisabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # AWS管理ポリシー: Managed-AllViewer（クエリ・ヘッダを全部オリジンへ転送する）
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }

  # 注意: ここに custom_error_response を置くと全ビヘイビア（/api/* を含む）に適用され、
  # APIの403/404が「200 + index.html」に化けてエラーが見えなくなる。
  # SPAのフォールバックは aws_cloudfront_function.spa_fallback でデフォルトビヘイビアだけに適用する

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # アジア含む主要リージョンをカバーしつつ低コストなプラン
  price_class = "PriceClass_200"

  tags = { Name = "${var.project_name}-frontend" }
}
