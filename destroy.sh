#!/usr/bin/env bash
set -euo pipefail

# AWS上のTodoアプリを全て削除するスクリプト。
# 課金を止めるため、インフラ一式を terraform destroy する。

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$PROJECT_ROOT/infra"

echo "=== 1/3: フロントエンド用S3バケットを空にする ==="
BUCKET=$(cd "$INFRA_DIR" && terraform output -raw frontend_bucket_name 2>/dev/null || true)
if [ -n "${BUCKET:-}" ]; then
    echo "  $BUCKET を空にします"
    aws s3 rm "s3://$BUCKET" --recursive || true
fi

echo "=== 2/3: インフラを削除 ==="
echo "  CloudFrontの削除には15〜20分かかることがあります"
(cd "$INFRA_DIR" && terraform destroy -auto-approve -input=false)

echo "=== 3/3: state保存用バケット（残しても課金はほぼ0） ==="
echo "  消す場合は次を実行してください:"
echo "    cd infra/bootstrap && terraform destroy -auto-approve"

echo ""
echo "=== 削除完了 ==="
echo "AWSコンソールで RDS / ECS / ALB が消えていることを確認してください。"
