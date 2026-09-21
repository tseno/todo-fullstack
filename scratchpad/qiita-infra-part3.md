# 【Terraform × AWS】Todoアプリのインフラをゼロから理解する（3/3）

> この記事は、Todoリストアプリのインフラ構成を初心者の視点で解説するシリーズの3つ目です。
> バックエンド編（1/3）・フロントエンド編（2/3）を先に読むと理解がスムーズです。

**シリーズ記事**: [1/3 バックエンド編](https://qiita.com/tseno/items/d2df1bdf15788d3b7011) ｜ [2/3 フロントエンド編](https://qiita.com/tseno/items/ec943d5312e8c5936728) ｜ **3/3 インフラ編（この記事）**

## この記事でわかること

- Terraform でインフラをコード管理（IaC）する流れ
- VPC・サブネット・セキュリティグループという考え方
- ECS Fargate / ALB / RDS / S3 / CloudFront の役割分担
- 低コストに抑える設計のポイント
- デプロイと削除の手順、つまずきやすいポイント

## 技術スタック


| 技術                        | 役割                 |
| ------------------------- | ------------------ |
| Terraform                 | インフラをコードで管理する（IaC） |
| Amazon VPC                | ネットワークの区画          |
| Amazon ECS（Fargate）       | バックエンドを動かす         |
| Application Load Balancer | リクエストの振り分け         |
| Amazon RDS                | PostgreSQL         |
| Amazon S3 + CloudFront    | フロントエンドの配信         |
| Amazon ECR                | Dockerイメージの保管      |
| Amazon Cognito            | 認証                 |
| GitHub Actions            | CI/CD（OIDCでAWS認証）  |


---

## そもそも Terraform とは

**Infrastructure as Code（IaC）** のツールです。AWSコンソールをポチポチ操作する代わりに、**インフラの構成をコードで書きます**。

```hcl
resource "aws_db_instance" "main" {
  engine         = "postgres"
  instance_class = "db.t4g.micro"
  allocated_storage = 20
}
```

### コードで書くメリット


| メリット    | 内容                              |
| ------- | ------------------------------- |
| 再現性     | 何度でも同じ構成を作れる                    |
| 差分が見える  | `terraform plan` で「何が変わるか」を事前確認 |
| レビューできる | 変更をGitで管理し、PRで確認できる             |
| 消すのも簡単  | `terraform destroy` で一括削除       |


**学習用途では「消しやすい」ことが特に重要**です。手動構築だと削除漏れで課金が続きますが、Terraformなら1コマンドで確実に消せます。

---

## 全体構成（本番）

<!-- ※ Qiitaの編集画面に docs/aws-architecture.png をドラッグ＆ドロップでアップロードし、
     下の画像URLをアップロード後のものに差し替えてください -->

![本番アーキテクチャ（AWS / 低コスト構成）](docs/aws-architecture.png)

ポイントは **「ブラウザから見える入口はCloudFrontだけ」** ということです。フロントもAPIも同じオリジンになるため、本番ではCORSが不要になります。

## ファイル構成

```
infra/
├── main.tf          # プロバイダとstate（管理情報）の保存先
├── variables.tf     # 入力変数
├── network.tf       # VPC・サブネット・セキュリティグループ
├── rds.tf           # PostgreSQL
├── ecs.tf           # Fargateでコンテナを動かす
├── alb.tf           # ロードバランサー
├── cloudfront.tf    # S3 + CloudFrontで配信
├── ecr.tf           # コンテナイメージの保管場所
├── cognito.tf       # 認証
├── github_oidc.tf   # CI/CD用のIAMロール
├── outputs.tf       # 出力値
└── bootstrap/       # state保存用S3バケット（初回だけ実行）
```

---

## 「state」という考え方

Terraformは **「今のインフラがどうなっているか」を記録したファイル（state）** を持ちます。

```
terraform.tfstate  ← 「VPCを1つ作った」「RDSを1つ作った」という記録
```

この記録があるから「既にあるものは作らない」「変わった部分だけ更新する」ができます。

### なぜS3に置くのか

```hcl
backend "s3" {
  bucket       = "todo-fullstack-tfstate-123456789012"   # アカウントIDを含む
  key          = "todo-fullstack/terraform.tfstate"
  region       = "ap-northeast-1"
  use_lockfile = true
}
```

- **ローカルに置くと**、PCを変えたときにstateがなくなり管理不能になる
- **S3に置くと**、GitHub Actions からも同じstateを参照できる
- `use_lockfile = true` で**同時実行を防ぐ**（ロック）

初回だけ `infra/bootstrap` を実行してstate用バケットを作ります（S3バケット自身はS3バックエンドでは作れないため）。

---

## 1. ネットワーク（network.tf）

### VPCとサブネット

**VPC** = AWSの中に作る「専用のネットワーク空間」です。

```
VPC: 10.0.0.0/16
├── public-a   10.0.1.0/24   ← インターネットから直接届く
├── public-c   10.0.2.0/24
├── private-a  10.0.11.0/24  ← インターネットから届かない
└── private-c  10.0.12.0/24
```

**サブネット** = VPCの中の区画です。`public` はインターネットゲートウェイへの経路を持ち、`private` は持ちません。

### なぜ2つのAZに分けるのか


| 理由     | 内容                     |
| ------ | ---------------------- |
| ALBの要件 | ロードバランサーは2つ以上のAZが必要    |
| RDSの要件 | DBサブネットグループは2つ以上のAZが必要 |
| 可用性    | 1つのAZが障害でも動き続ける        |


### セキュリティグループ（SG）

**SG = ファイアウォール**です。「どこから、どのポートへ」を制限します。


| SG   | 許可する入口                   | 理由         |
| ---- | ------------------------ | ---------- |
| ALB用 | 80番 / **CloudFrontから**のみ | 直接アクセスを防ぐ  |
| ECS用 | 8080番 / **ALBから**のみ      | ALB経由以外を防ぐ |
| RDS用 | 5432番 / **ECSから**のみ      | DBを外部から隠す  |


```hcl
resource "aws_security_group" "rds" {
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]  # ECSからだけ
  }
}
```

**「必要な通信だけを通す」** のがセキュリティの基本です。

### CloudFrontのIPレンジをどう指定するか

ALBを「CloudFrontからだけ」に絞るには、CloudFrontのIPレンジが必要です。AWSが**プレフィックスリスト**として公開しています。

```hcl
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}
```

> ⚠️ `data.aws_prefix_list` という似たデータソースがありますが、**CloudFrontのリストは取得できません**（内部的に使うAPIが違うため）。`aws_ec2_managed_prefix_list` を使います。ここは実際にハマったポイントです。

---

## 2. なぜ NAT Gateway を作らないのか

**これがこの構成で一番のコスト削減ポイント**です。

### 通常の構成

```
privateサブネットのECSタスク → NAT Gateway → インターネット
```

NAT Gateway を使うと、プライベートな場所から安全に外に出られます。しかし…


| 項目                | 料金             |
| ----------------- | -------------- |
| NAT Gateway の時間料金 | **約$0.062/時間** |
| データ処理料金           | 別途             |
| **月額**            | **約$45**       |


**たった1つで月$45**かかります。ALBやRDSより高い場合もあります。

### この構成の回避策

```
publicサブネットのECSタスク（パブリックIP付き） → Internet Gateway → インターネット
```

ECSタスクを**パブリックサブネットに置き、パブリックIPを付与**します。これでECRからイメージを取得でき、CloudWatchにもログを送れます。

```hcl
network_configuration {
  assign_public_ip = true
  subnets          = [aws_subnet.public_a.id, aws_subnet.public_c.id]
  security_groups  = [aws_security_group.ecs.id]
}
```


|        | NAT Gateway あり | なし（この構成）      |
| ------ | -------------- | ------------- |
| 月額     | +$45           | **$0**        |
| セキュリティ | ◎ タスクが外から見えない  | △ パブリックIPを持つ  |
| 入口の制限  | SGで制御          | **SGで制御（同じ）** |


**トレードオフは理解しておくべき**です。ALBのSGで「CloudFrontからだけ」に絞っているため、実質的な露出は限定的ですが、本格運用ではNAT Gatewayを使う構成が一般的です。

---

## 3. データベース（rds.tf）

```hcl
resource "aws_db_instance" "main" {
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"   # 最小クラス

  allocated_storage = 20
  multi_az          = false         # シングルAZ（約半額）
  publicly_accessible = false       # 外部から接続不可

  skip_final_snapshot = true        # 削除時にスナップショットを残さない
  deletion_protection = false       # 削除できるようにする
}
```

### コストを抑える設定


| 設定                            | 効果                  |
| ----------------------------- | ------------------- |
| `db.t4g.micro`                | 最小スペック（Gravitonは安い） |
| `multi_az = false`            | 冗長化しない（約50%削減）      |
| `publicly_accessible = false` | privateサブネットに配置     |


### パスワードをコードに書かない

```hcl
resource "random_password" "db" {
  length  = 40
  special = false
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/db_password"
  type  = "SecureString"
  value = random_password.db.result
}
```

パスワードは**SSMパラメータストア（暗号化）** に保存し、ECSタスク起動時に注入します。コードにもGitにも残りません。

---

## 4. コンテナ（ecs.tf）

### Fargateとは

**サーバー（EC2）の管理が不要なコンテナ実行環境**です。「0.5vCPU / 1GB」のようにスペックを指定するだけで動きます。

```hcl
resource "aws_ecs_task_definition" "backend" {
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"   # 0.5 vCPU
  memory                   = "1024"  # 1 GB

  runtime_platform {
    cpu_architecture = "ARM64"       # Graviton（x86より安い）
  }
}
```

### ARM64 を選ぶ理由

Graviton（ARM64）は **x86より約20%安い**です。ただし**イメージもARM64でビルドする必要**があります。

```bash
docker buildx build --platform linux/arm64 ...
```

> Apple SiliconのMacなら、Dockerデーモンがarm64で動いているため通常の `docker build` でそのままARM64イメージが作れます。

### 環境変数と秘密情報の注入

```hcl
environment = [
  { name = "SPRING_DATASOURCE_URL",      value = "jdbc:postgresql://..." },
  { name = "CORS_ALLOWED_ORIGINS",       value = "https://xxx.cloudfront.net" },
]

secrets = [
  { name = "SPRING_DATASOURCE_PASSWORD", valueFrom = aws_ssm_parameter.db_password.arn }
]
```

- **environment**: 秘密でない設定
- **secrets**: SSMから取り出す秘密情報

---

## 5. ロードバランサー（alb.tf）

CloudFrontから来たリクエストをECSタスクへ振り分けます。

```hcl
resource "aws_lb_target_group" "backend" {
  port        = 8080
  target_type = "ip"   # Fargate(awsvpc)はIPで登録する

  health_check {
    path     = "/api/hello"   # ヘルスチェック用エンドポイント
    matcher  = "200"
    interval = 30
    timeout  = 5
  }
}
```

### `target_type = "ip"` の理由

Fargateは `awsvpc` ネットワークモードで、タスクごとに固有のIPを持ちます。インスタンスIDではないため `ip` を指定します。

### なぜ `/api/hello` が必要か

ALBのヘルスチェックは**JWTを送れません**。そのため認証不要のエンドポイントを用意し、バックエンドのSecurityConfigでも許可しています。

---

## 6. 配信（cloudfront.tf）

### S3 と CloudFront の役割


| サービス       | 役割                           |
| ---------- | ---------------------------- |
| S3         | 静的ファイル（HTML/JS/CSS）の置き場      |
| CloudFront | CDN・HTTPS終端・**2つのオリジンの振り分け** |


```hcl
# /* は S3 へ
default_cache_behavior {
  target_origin_id = "s3-frontend"
}

# /api/* は ALB へ（キャッシュしない）
ordered_cache_behavior {
  path_pattern           = "/api/*"
  target_origin_id       = "alb-backend"
  cache_policy_id        = "4135ea2d-..."  # CachingDisabled
  origin_request_policy_id = "216adef6-..." # AllViewer
}
```

**`/api/*` だけキャッシュを無効化**し、`Authorization` ヘッダもそのまま転送します。

### S3を直接公開しない（OAC）

```hcl
resource "aws_cloudfront_origin_access_control" "frontend" {
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
```

**OAC（Origin Access Control）** を使うと、S3を非公開のままCloudFrontだけが読めるようになります。

### SPAフォールバック

Next.jsの静的エクスポートでは、未知のパスでも `index.html` を返したい場合があります。**CloudFront Function** で実現します。

```js
function handler(event) {
  var uri = event.request.uri;
  var lastSegment = uri.split('/').pop();
  if (lastSegment.indexOf('.') === -1) {
    event.request.uri = '/index.html';   // 拡張子がなければ index.html へ
  }
  return event.request;
}
```

**重要**: これを**デフォルトビヘイビア（S3）にだけ**紐づけます。`/api/*` には適用しません。

> ⚠️ `custom_error_response`（403/404 → index.html + 200）を使う方法もありますが、**配信全体に適用されてAPIのエラーまで隠してしまう**ため、この構成では使いません。ここは実際に一番ハマったポイントです（後述）。

---

## 7. イメージ置き場（ecr.tf）

```hcl
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true   # destroy時にイメージが残っていても削除できる
}
```

**`force_delete = true`** がないと、イメージが残っている状態で `terraform destroy` が失敗します。

---

## 8. 認証（cognito.tf）

```hcl
resource "aws_cognito_user_pool_client" "main" {
  generate_secret              = false        # SPA（公開クライアント）
  allowed_oauth_flows          = ["code"]     # 認可コードフロー
  supported_identity_providers = ["COGNITO"]

  callback_urls = [
    "http://localhost:3000",                  # 開発用
    "https://${aws_cloudfront_distribution.frontend.domain_name}",  # 本番用
  ]
}
```

リダイレクト先は**許可リストに登録したURLしか使えません**（オープンリダイレクト対策）。

---

## 9. CI/CD用のIAM（github\_oidc.tf）

### OIDC とは

GitHub Actions からAWSを操作する方法は2つあります。


| 方法                | 安全性                    |
| ----------------- | ---------------------- |
| アクセスキーをSecretsに保存 | △ 漏れると悪用される。ローテーションが必要 |
| **OIDC（一時トークン）**  | ◎ キーを持たない。短時間だけ有効      |


```hcl
condition {
  test     = "StringLike"
  variable = "token.actions.githubusercontent.com:sub"
  values = [
    "repo:${var.github_repo}:ref:refs/heads/main",   # mainブランチ
    "repo:${var.github_repo}:pull_request",
  ]
}
```

**「どのリポジトリの、どのブランチから」を条件で制限**できるのがOIDCの強みです。

> この構成ではCI/CDが `terraform apply` まで行うため、ロールに `AdministratorAccess` を付けています。個人の学習用リポジトリという前提です。実務では必要な権限だけに絞ります。

---

## 本番のリクエストの流れ

```
ブラウザ
  ↓ https://xxx.cloudfront.net/api/todos（JWT付き）
CloudFront
  ↓ /api/* なのでALBへ転送（キャッシュなし・ヘッダ全部）
ALB
  ↓ ヘルスチェック済みのECSタスクへ
ECS Fargate（Spring Boot）
  ↓ セキュリティグループで絞られた5432番へ
RDS（PostgreSQL）
```

フロントエンドの表示は:

```
ブラウザ
  ↓ https://xxx.cloudfront.net/
CloudFront
  ↓ /* なのでS3へ（キャッシュあり）
S3（index.html / JS / CSS）
```

---

## デプロイの流れ

一括デプロイ用のスクリプトを用意しています。

```bash
./deploy.sh
```

内部では6ステップです。


| 手順  | 内容                                     |
| --- | -------------------------------------- |
| 1   | state保存用のS3バケットを作成（bootstrap）          |
| 2   | stateをS3へ移行し、インフラを一式 `terraform apply` |
| 3   | Terraform outputs を取得                  |
| 4   | バックエンドイメージをARM64でビルドしてECRへpush         |
| 5   | フロントエンドをビルドしてS3へ配置、CloudFrontを無効化      |
| 6   | ECSサービスを更新して安定を待つ                      |


**順番が重要**です。Terraformを先に適用しないと、ECR/CloudFront/S3などの「出力値」が存在せず、イメージのpush先も決まりません。

## 削除の流れ

```bash
./destroy.sh
```

1. フロント用S3バケットを空にする
2. `terraform destroy` で全リソースを削除


| リソース             | 所要時間          |
| ---------------- | ------------- |
| ECSサービス          | 約7分           |
| RDS              | 約2分           |
| CloudFront       | 約3分           |
| Internet Gateway | 約10分（依存の解放待ち） |


**Internet Gatewayが一番時間がかかります**。ALBのネットワークインターフェースが解放されるのを待つためで、異常ではありません。

---

## つまずいたポイント（初学者がハマりやすい）

実際にこの構成をデプロイして遭遇した問題です。**同じエラーで悩まないように**まとめます。

### ① プレフィックスリストが取得できない

```
Error: no matching EC2 Prefix List found
```

`data.aws_prefix_list` は `DescribePrefixLists` というAPIを使いますが、**CloudFrontのプレフィックスリストはこのAPIでは返りません**。`data.aws_ec2_managed_prefix_list` に変えると取得できます。

### ② ECSの設定値は小文字

```
InvalidParameterException: Invalid setting 'value'
```

```hcl
setting {
  name  = "containerInsights"
  value = "disabled"   # "DISABLED" ではない
}
```

### ③ CloudFrontのマネージドポリシーIDは更新される

```
NoSuchOriginRequestPolicy: The specified origin request policy does not exist.
```

CloudFrontのマネージドポリシーはIDが**世代交代することがあります**。実際に使えるIDを確認しましょう。

```bash
aws cloudfront list-origin-request-policies --type managed
aws cloudfront list-cache-policies --type managed
```

### ④ `custom_error_response` がAPIのエラーを隠す【最重要】

これが**一番ハマった**ポイントです。

SPAのフォールバックとして、よく次の設定を書きます。

```hcl
custom_error_response {
  error_code         = 403
  response_code      = 200
  response_page_path = "/index.html"
}
```

しかしこれは **配信全体（`/api/*` を含む）に適用**されます。結果:

```
APIが403を返す
  → CloudFrontが「index.html + 200」に変換
  → フロントは200なのでHTMLをJSONとして読もうとする
  → SyntaxError
  → 「なぜか動かない」のに、エラーが見えない
```

**エラーが「成功」に見えてしまう**ため、原因調査が非常に困難になります。

対策は **「SPAフォールバックをフロントのパスだけに限定する」** ことです。

```hcl
# 配信全体の custom_error_response は使わない
# 代わりに、S3ビヘイビアにだけ CloudFront Function を紐づける
default_cache_behavior {
  function_association {
    event_type   = "viewer-request"
    function_arn = aws_cloudfront_function.spa_fallback.arn
  }
}
```

**「便利な設定が、どこまで影響するか」を必ず確認する**という教訓です。

### ⑤ S3バケットが削除できない

```
BucketNotEmpty: The bucket you tried to delete is not empty
```

`terraform destroy` はバケット内にオブジェクトがあると失敗します。

```hcl
resource "aws_s3_bucket" "frontend" {
  force_destroy = true   # 中身ごと削除する
}
```

### ⑥ 自動スナップショットは手動削除できない

```
InvalidDBSnapshotState: automated snapshots cannot be deleted.
```

RDSのスナップショットには2種類あります。


| 種類             | 手動削除  | 課金           |
| -------------- | ----- | ------------ |
| 手動スナップショット     | ○     | 常に有料         |
| **自動スナップショット** | **×** | インスタンス削除後は有料 |


自動スナップショットは**RDSがライフサイクルを管理**しており、インスタンスを削除すると自動で消えます（非同期のため一時的に残って見えることがあります）。

---

## コスト設計まとめ


| リソース               | スペック                  | 月額目安       |
| ------------------ | --------------------- | ---------- |
| ALB                | Application           | 約$18       |
| ECS Fargate        | 0.5vCPU / 1GB / ARM64 | 約$18       |
| RDS                | db.t4g.micro + 20GB   | 約$17       |
| CloudFront         | PriceClass\_200       | 数円         |
| S3 / ECR / Cognito | 極小                    | ほぼ$0       |
| **合計**             |                       | **約$50/月** |


### コストを下げた工夫


| 工夫                          | 削減効果       |
| --------------------------- | ---------- |
| NAT Gateway を作らない           | **約$45/月** |
| RDSをシングルAZに                 | 約50%       |
| FargateをARM64に              | 約20%       |
| CloudFrontをPriceClass\_200に | 最安プラン      |
| ログ保持を7日に                    | ストレージ削減    |


**ただし「常時起動すると月$50」という点は重要です。学習用途なら使い終わったら削除する**のが鉄則です。

```
デプロイ → 数時間〜数日使う → destroy
```

この流れなら実費は数ドルで済みます。

---

## まとめ

- **Terraform**: インフラをコードで管理。再現も削除も簡単
- **VPC / サブネット / SG**: ネットワークを区切って、必要な通信だけ通す
- **ECS Fargate**: サーバー管理不要。ARM64でコスト削減
- **ALB**: ヘルスチェックで正常なタスクにだけ振り分け
- **S3 + CloudFront**: 静的配信とAPI転送を1つの入口にまとめる
- **Cognito**: 認証をマネージドサービスに任せる
- **OIDC**: アクセスキーを持たずにCI/CDからAWSを操作

インフラは「見えない」分だけつまずきやすいですが、**エラーが出たときは「どの層で起きているか」を切り分ける**のが解決の近道です。

3記事を通して、**「画面 → HTTP → Spring Security → DB」** と **「Terraform → AWS → コンテナ」** の全体像が見えたら嬉しいです。

---

> **シリーズ記事**
>
> - \[1/3\] [Spring Boot × Kotlin バックエンド編](https://qiita.com/tseno/items/d2df1bdf15788d3b7011)
> - \[2/3\] [Next.js フロントエンド編](https://qiita.com/tseno/items/ec943d5312e8c5936728)
> - \[3/3\] [Terraform × AWS インフラ編](https://qiita.com/tseno/items/4621aee6401f2ebe0d51)（この記事）

