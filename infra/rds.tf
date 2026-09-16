# RDS (PostgreSQL) の構成
# 低コスト方針: db.t4g.micro / シングルAZ / ストレージ20GB
# terraform destroy で完全に消せるよう skip_final_snapshot = true にしている

resource "random_password" "db" {
  length  = 40
  special = false
}

# DBパスワードはコードに書かずSSMパラメータストアに保存し、ECSタスク起動時に注入する
resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/db_password"
  type  = "SecureString"
  value = random_password.db.result
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_c.id]

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  db_name           = var.db_name
  username          = var.db_username
  password          = random_password.db.result
  port              = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  auto_minor_version_upgrade = true
  backup_retention_period    = 7

  # 学習用のため気軽に作り直せる設定。本格運用では見直す
  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = "${var.project_name}-db" }
}
