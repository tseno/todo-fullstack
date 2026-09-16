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

## アーキテクチャ

### ローカル開発

```
Browser → Next.js (localhost:3000)
              ↓ /api/*（CORS経由）
          Spring Boot (localhost:8080)
              ↓
          PostgreSQL (Docker Compose)
```

### 本番（AWS）

```
Browser → CloudFront (https://xxx.cloudfront.net)
              ├─ /*       → S3（Next.jsの静的エクスポート）
              └─ /api/*   → ALB → ECS Fargate（Kotlin/Spring Boot, ARM64）
                                      ↓
                                  RDS PostgreSQL（プライベートサブネット）
認証: Cognito Hosted UI（認可コードフロー + PKCE）
```

- 低コスト構成: NAT Gatewayなし（ECSタスクはパブリックサブネット+パブリックIP）、
  RDSは db.t4g.micro シングルAZ、Fargate 0.5vCPU/1GB タスク1台。月額概算 $40 前後。
  `terraform destroy` で完全に破棄できる。
- フロントエンドは `/api/*` を同一オリジンで呼ぶため、本番ではCORSが不要になる

## 技術スタック

| レイヤー | 技術 |
|---|---|
| フロントエンド | Next.js (App Router) / TypeScript |
| バックエンド | Kotlin / Spring Boot / Gradle (Kotlin DSL) |
| データベース | PostgreSQL (AWS RDS) |
| 認証 | Amazon Cognito（Hosted UI / PKCE） |
| インフラ | Terraform |
| デプロイ先 | AWS (ECS Fargate / S3 + CloudFront / ECR / ALB) |
| CI/CD | GitHub Actions（OIDCでAWS認証） |
| ローカル開発環境 | Docker Compose |

## ディレクトリ構成

```
todo-fullstack/
├── backend/         # Spring Boot アプリケーション（API）+ Dockerfile
├── frontend/        # Next.js アプリケーション（画面、静的エクスポート）
├── infra/           # Terraform コード（AWSインフラ定義）
│   └── bootstrap/   # state保存用S3バケットを作る初回用の最小構成
├── compose.yml      # ローカル開発環境の起動定義
└── .env.example     # ローカル用環境変数のテンプレート
```

## セットアップ（ローカル開発）

### 1. PostgreSQLを起動

```bash
cp .env.example .env
docker compose up -d
```

### 2. バックエンドを起動

```bash
cd backend
./gradlew bootRun
# http://localhost:8080/api/hello で動作確認
```

DB接続情報は環境変数 `SPRING_DATASOURCE_URL` / `SPRING_DATASOURCE_USERNAME` /
`SPRING_DATASOURCE_PASSWORD` で上書きできる（未設定ならlocalhostのPostgresに接続）。

### 3. フロントエンドを起動

```bash
cd frontend
cp .env.example .env.local   # Cognitoのドメイン等を設定
npm install
npm run dev
# http://localhost:3000
```

`.env.local` はgitignoreされているのでコミットされない。

## 本番デプロイ

初回のみ以下を実施する（以降はmainへのpushだけで自動デプロイされる）。

### 1. state保存用のS3バケットを作成

```bash
cd infra/bootstrap
terraform init
terraform apply
cd ../..
```

### 2. stateをS3へ移行してインフラを一式適用

```bash
cd infra
terraform init -migrate-state   # 既存のローカルstate（Cognito）をS3へ移行する
terraform apply                 # 内容を確認して yes
```

適用が終わったら `terraform output` で各種URLが確認できる。

### 3. GitHub Actions用のロールを設定

```bash
terraform output -raw github_deploy_role_arn
```

表示されたARNを、GitHubリポジトリの **Settings → Secrets and variables → Actions →
Variables** に `AWS_DEPLOY_ROLE_ARN` として登録する。

### 4. デプロイ

mainブランチへpushすると deploy ワークフローが走り、
Terraform適用 → バックエンドイメージのpush(ECS) → フロントエンドのS3アップロード +
CloudFront無効化まで自動で行われる。

## CI/CD

| ワークフロー | トリガー | 内容 |
|---|---|---|
| `ci.yml` | PR作成 | バックエンドのテスト（Postgresコンテナ起動）、フロントエンドのビルド |
| `deploy.yml` | mainへのpush | Terraform apply → ECR push → ECSデプロイ → S3 sync + CloudFront invalidate |

AWS認証はOIDC（長期アクセスキーなし）。`terraform apply` はTerraform側のstateロック（S3 lockfile）で競合を防ぐ。

## 学習の進め方

以下のステップで段階的に構築している。

1. ✅ リポジトリ雛形・Docker Compose環境構築
2. ✅ バックエンド基礎（Spring Boot + Kotlin、Todo CRUD API）
3. ✅ 認証（Cognito連携、PKCE、ユーザーごとのTodo管理）
4. ✅ フロントエンド（Next.js 画面実装、静的エクスポート）
5. ✅ インフラ構築（Terraform: VPC/RDS/ECS/ALB/CloudFront/S3/ECR）
6. ✅ CI/CD（GitHub Actions: テスト・デプロイ自動化）

## 補足

個人の学習を目的としたリポジトリです。コード中のコメントも学習用に平易な日本語で記述しています。
