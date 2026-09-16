# 入力変数の定義。基本的にはデフォルト値で動く

variable "aws_region" {
  description = "AWSリージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "リソース名のプレフィックス"
  type        = string
  default     = "todo-fullstack"
}

variable "github_repo" {
  description = "CI/CDを許可するGitHubリポジトリ（owner/repo形式）"
  type        = string
  default     = "tseno/todo-fullstack"
}

variable "db_name" {
  description = "RDSのデータベース名"
  type        = string
  default     = "todo"
}

variable "db_username" {
  description = "RDSのマスターユーザー名"
  type        = string
  default     = "todo"
}
