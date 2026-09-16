# バックエンドのコンテナイメージを保存するECRリポジトリ
# フロントエンドは静的ファイルなのでイメージは不要（S3へデプロイする）

resource "aws_ecr_repository" "backend" {
  name = "${var.project_name}-backend"

  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  # terraform destroy のときにイメージが残っていてもリポジトリを消せるようにする
  force_delete = true
}
