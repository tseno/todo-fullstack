#!/usr/bin/env bash
set -euo pipefail

# AWSへTodoアプリ一式をデプロイするスクリプト。
# 前提:
#   - aws CLI に認証済みであること
#   - Docker (buildx) が起動していること
#   - terraform がインストールされていること
#
# 実行内容:
#   1. state保存用のS3バケットを作成（bootstrap / 初回のみ有効）
#   2. 既存のローカルstateをS3へ移行し、インフラを一式適用
#   3. バックエンドのDockerイメージをarm64でビルドしてECRへpush
#   4. フロントエンドを静的エクスポートしてS3へ配置、CloudFrontを無効化
#   5. ECSサービスを更新して安定を待つ

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$PROJECT_ROOT/infra"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
REGION="ap-northeast-1"

# .env.local はローカル開発用（APIベースURLがlocalhost:8080）なので、
# 本番ビルド中は退避させて NEXT_PUBLIC_API_BASE_URL が埋め込まれないようにする
ENV_LOCAL="$FRONTEND_DIR/.env.local"
ENV_LOCAL_BAK="$FRONTEND_DIR/.env.local.deploybak"
restore_env_local() {
    if [ -f "$ENV_LOCAL_BAK" ]; then
        mv "$ENV_LOCAL_BAK" "$ENV_LOCAL"
    fi
}
trap restore_env_local EXIT

echo "=== 1/6: state保存用バケットを作成 (bootstrap) ==="
(cd "$INFRA_DIR/bootstrap" && terraform init -input=false && terraform apply -auto-approve -input=false)

echo "=== 2/6: stateをS3へ移行してインフラを適用 ==="
# ローカルstateに中身があるときだけ移行する（移行済みなら通常のinit）
if [ -s "$INFRA_DIR/terraform.tfstate" ]; then
    echo "  ローカルstateを検出したためS3へ移行します"
    (cd "$INFRA_DIR" && terraform init -migrate-state -force-copy -input=false)
else
    (cd "$INFRA_DIR" && terraform init -input=false)
fi
(cd "$INFRA_DIR" && terraform apply -auto-approve -input=false)

echo "=== 3/6: Terraform outputs を取得 ==="
ECR_URL=$(cd "$INFRA_DIR" && terraform output -raw ecr_repository_url)
BUCKET=$(cd "$INFRA_DIR" && terraform output -raw frontend_bucket_name)
CF_ID=$(cd "$INFRA_DIR" && terraform output -raw cloudfront_distribution_id)
HOSTED_UI=$(cd "$INFRA_DIR" && terraform output -raw hosted_ui_domain)
CLIENT_ID=$(cd "$INFRA_DIR" && terraform output -raw user_pool_client_id)
CLUSTER=$(cd "$INFRA_DIR" && terraform output -raw ecs_cluster_name)
SERVICE=$(cd "$INFRA_DIR" && terraform output -raw ecs_service_name)
echo "  ECR:        $ECR_URL"
echo "  S3:         $BUCKET"
echo "  CloudFront: $CF_ID"

echo "=== 4/6: バックエンドイメージをbuild & push (linux/arm64) ==="
# ECSタスクはARM64(Graviton)なのでarm64イメージが必要。
# buildxが無い環境でも、Dockerデーモンがarm64なら通常のbuildでarm64になる
DAEMON_ARCH=$(docker info --format '{{.Architecture}}')
if [ "$DAEMON_ARCH" != "aarch64" ] && [ "$DAEMON_ARCH" != "arm64" ]; then
    echo "警告: Dockerデーモンが $DAEMON_ARCH です。ECSタスクはARM64のため起動しない可能性があります" >&2
fi
aws ecr get-login-password --region "$REGION" |
    docker login --username AWS --password-stdin "${ECR_URL%%/*}"
docker build -t "${ECR_URL}:latest" "$PROJECT_ROOT/backend"
docker push "${ECR_URL}:latest"

echo "=== 5/6: フロントエンドをbuildしてS3へアップロード ==="
if [ -f "$ENV_LOCAL" ]; then
    mv "$ENV_LOCAL" "$ENV_LOCAL_BAK"
fi
(cd "$FRONTEND_DIR" &&
    # NODE_ENV=production でも devDependencies（tailwindcss等）を入れる
    npm ci --include=dev &&
    # 前回のビルドキャッシュが残っていると失敗することがあるため消す
    rm -rf .next &&
    NEXT_PUBLIC_COGNITO_DOMAIN="$HOSTED_UI" \
    NEXT_PUBLIC_COGNITO_CLIENT_ID="$CLIENT_ID" \
    npm run build)
restore_env_local

# 本番ビルドにlocalhostのAPI URLが混ざっていないか確認する
if grep -rq "localhost:8080" "$FRONTEND_DIR/out"; then
    echo "エラー: ビルド成果物に localhost:8080 が含まれています（同一オリジンになっていません）" >&2
    exit 1
fi

aws s3 sync "$FRONTEND_DIR/out" "s3://$BUCKET" --delete
aws cloudfront create-invalidation --distribution-id "$CF_ID" --paths "/*" --no-cli-pager > /dev/null

echo "=== 6/6: ECSサービスを更新して安定を待つ（数分かかります） ==="
aws ecs update-service --cluster "$CLUSTER" --service "$SERVICE" --force-new-deployment --no-cli-pager > /dev/null
aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"

echo ""
echo "=== デプロイ完了 ==="
(cd "$INFRA_DIR" && terraform output cloudfront_domain)
echo ""
echo "削除する場合は ./destroy.sh を実行してください。"
