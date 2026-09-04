# todo-fullstack

Kotlin + Spring Boot + Next.js + AWS で構築する、学習用のフルスタックTodoアプリです。

## 目的

- Kotlin + Spring Boot によるバックエンドAPI開発を学ぶ
- Next.js によるフロントエンド開発を学ぶ
- Terraform によるAWSインフラのコード管理（IaC）を学ぶ
- Amazon Cognito を使ったユーザー認証の仕組みを学ぶ
- GitHub Actions による CI/CD を学ぶ
- 学んだ内容をQiitaにシリーズ記事としてまとめる

ユーザー管理を自前で実装するのではなく Amazon Cognito（マネージドサービス）に任せることで、
認証まわりの実装コストとセキュリティリスクを下げています。

## 技術スタック

| レイヤー | 技術 |
|---|---|
| フロントエンド | Next.js (App Router) / TypeScript |
| バックエンド | Kotlin / Spring Boot / Gradle (Kotlin DSL) |
| データベース | PostgreSQL (AWS RDS) |
| 認証 | Amazon Cognito |
| インフラ | Terraform |
| デプロイ先 | AWS (ECS Fargate / S3 + CloudFront / ECR) |
| CI/CD | GitHub Actions |
| ローカル開発環境 | Docker Compose |

## ディレクトリ構成

```
todo-fullstack/
├── backend/   # Spring Boot アプリケーション（API）
├── frontend/  # Next.js アプリケーション（画面）
├── infra/     # Terraform コード（AWSインフラ定義）
└── docker-compose.yml  # ローカル開発環境の起動定義
```

## セットアップ（準備中）

現時点ではまだ各アプリケーションの雛形を作成中です。将来的には以下のコマンドだけで
ローカル環境（backend / frontend / PostgreSQL）が一括起動できるようにする予定です。

```bash
docker compose up
```

## 学習の進め方

このリポジトリは以下のステップで段階的に構築しています。

1. リポジトリ雛形・Docker Compose環境構築
2. バックエンド基礎（Spring Boot + Kotlin、Todo CRUD API）
3. 認証（Cognito連携）
4. フロントエンド（Next.js 画面実装）
5. インフラ構築（Terraform）
6. CI/CD（GitHub Actions）

## 補足

個人の学習を目的としたリポジトリです。コード中のコメントも学習用に平易な日本語で記述しています。
