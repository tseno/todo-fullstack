# 【Spring Boot × Kotlin】Todoアプリのバックエンドをゼロから理解する（1/3）

> この記事は、Todoリストアプリのバックエンド実装を初心者の視点で解説するシリーズの1つ目です。
> 以降の記事でフロントエンドとインフラを解説します。

**シリーズ記事**: **1/3 バックエンド編（この記事）** ｜ [2/3 フロントエンド編](https://qiita.com/tseno/items/ec943d5312e8c5936728) ｜ [3/3 インフラ編](https://qiita.com/tseno/items/4621aee6401f2ebe0d51)

## この記事でわかること

- Spring Boot + Kotlin で REST API を作る基本的な流れ
- データベースモデル（Entity）の設計
- Controller → Service → Repository の3層アーキテクチャ
- AWS Cognito を使った JWT 認証の仕組み
- CORS 設定の意味と必要性

## 技術スタック


| 技術              | 役割         |
| --------------- | ---------- |
| Kotlin          | プログラミング言語  |
| Spring Boot     | Webフレームワーク |
| Spring Data JPA | データベースアクセス |
| PostgreSQL      | データベース     |
| AWS Cognito     | ユーザー認証     |
| Gradle          | ビルドツール     |


## プロジェクト構成

```
backend/src/main/kotlin/com/example/todo_backend/
├── TodoBackendApplication.kt  # アプリケーションの起動ポイント
├── Todo.kt                    # データベースのテーブル定義
├── TodoRepository.kt          # データベースへのアクセス
├── TodoService.kt             # ビジネスロジック
├── TodoController.kt          # REST APIの定義
├── TodoRequest.kt             # クライアントから受け取るデータの形式
├── TodoResponse.kt            # クライアントに返すデータの形式
├── SecurityConfig.kt          # 認証・認可の設定
├── WebConfig.kt               # CORS設定
└── HelloController.kt         # ヘルスチェック用エンドポイント
```

---

## 1. データベースモデル（Todo.kt）

まず、TodoがDBにどう保存されるかを定義します。

```kotlin
@Entity
class Todo {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long = 0

    var userId: String = ""
    var title: String = ""
    var description: String? = null
    var dueDate: LocalDate? = null

    @Enumerated(EnumType.STRING)
    var priority: TodoPriority = TodoPriority.MEDIUM
    var completed: Boolean = false
}
```

### アノテーションの意味


| アノテーション               | 意味                      |
| --------------------- | ----------------------- |
| `@Entity`             | このクラスはDBテーブルに対応する       |
| `@Id`                 | プライマリキー（各行の一意な識別子）      |
| `@GeneratedValue`     | DBが自動で番号を振る（1, 2, 3...） |
| `@Enumerated(STRING)` | 列挙型をDBに文字列として保存する       |


### `String?` の `?` とは

Kotlinでは `?` をつけると「nullでもOK」となります。`description` や `dueDate` は入力省略可能なので `String?` / `LocalDate?` としています。

### `userId` の役割

```kotlin
var userId: String = ""
```

このフィールドが「このTodoが誰のものか」を示します。Cognitoのユーザー識別子（`sub`）が保存され、**これがあることで他のユーザーのTodoを見られない**仕組みになっています。

---

## 2. レイヤーアーキテクチャ

このアプリでは **3層アーキテクチャ** を採用しています。

```
TodoController  →  TodoService  →  TodoRepository
（HTTP受信）       （ビジネスロジック）  （DB操作）
```

なぜわざわざ3つに分けるのか？

- **Controller**: HTTPリクエストの処理とレスポンスの返却だけに集中
- **Service**: 「ユーザーAのTodoしか操作できない」などのビジネスルールを担当
- **Repository**: SQLの実行だけを担当

これにより、各層の責務が明確になり、テストや変更が容易になります。

---

### Repository（TodoRepository.kt）

```kotlin
interface TodoRepository : JpaRepository<Todo, Long> {
    fun findByUserId(userId: String): List<Todo>
    fun findByIdAndUserId(id: Long, userId: String): Optional<Todo>
    fun existsByIdAndUserId(id: Long, userId: String): Boolean
}
```

Spring Data JPAの特徴は、**メソッド名から自動でSQLが生成される**ことです。

- `findByUserId(userId)` → `SELECT * FROM todo WHERE user_id = ?`
- `findByIdAndUserId(id, userId)` → `SELECT * FROM todo WHERE id = ? AND user_id = ?`
- `existsByIdAndUserId(id, userId)` → `SELECT COUNT(*) FROM todo WHERE id = ? AND user_id = ?`

すべてのクエリに `userId` が含まれているため、**他のユーザーのデータが取得されない**のが保証されています。

---

### Service（TodoService.kt）

```kotlin
@Service
class TodoService(val todoRepository: TodoRepository) {
    fun getTodosForUser(userId: String) =
        todoRepository.findByUserId(userId)

    fun createTodoForUser(userId: String, todo: Todo): Todo {
        todo.userId = userId
        return todoRepository.save(todo)
    }
}
```

Service層の責務は「**ログインユーザー自身のTodoのみ操作すること**」です。

作成時は `todo.userId = userId` でユーザーIDをセットしてから保存します。これにより「誰のTodoか」が確定します。

更新時は `findByIdAndUserId` で「そのユーザーのそのTodo」を探し、見つからない場合は404エラーを返します。

---

### Controller（TodoController.kt）

```kotlin
@RestController
@RequestMapping("/api")
class TodoController(val todoService: TodoService) {

    private fun Jwt.userId(): String =
        requireNotNull(this.subject) { "JWTにsubクレームがありません" }

    @GetMapping("/todos")
    fun getTodos(@AuthenticationPrincipal jwt: Jwt): List<TodoResponse> =
        todoService.getTodosForUser(jwt.userId()).map { TodoResponse(it) }

    @PostMapping("/todos")
    fun createTodo(
        @AuthenticationPrincipal jwt: Jwt,
        @Valid @RequestBody todoRequest: TodoRequest
    ): TodoResponse =
        TodoResponse(todoService.createTodoForUser(jwt.userId(), todoRequest.toEntity()))
}
```

### アノテーションの意味


| アノテーション                    | 意味                     |
| -------------------------- | ---------------------- |
| `@RestController`          | HTTPリクエストを受け取るコントローラー  |
| `@RequestMapping("/api")`  | 全エンドポイントのプレフィックス       |
| `@GetMapping`              | GETリクエスト（データ取得）        |
| `@PostMapping`             | POSTリクエスト（データ作成）       |
| `@AuthenticationPrincipal` | JWTからユーザー情報を取得         |
| `@Valid`                   | リクエストボディをバリデーション       |
| `@RequestBody`             | JSONリクエストボディをオブジェクトに変換 |
| `@PathVariable`            | URLの `{id}` 部分を変数に受け取る |


---

## 3. DTO（データ変換オブジェクト）

### TodoRequest（受け取る側）

```kotlin
data class TodoRequest(
    @field:NotBlank(message = "titleは必須です")
    @field:Size(max = 200, message = "titleは200文字以内で入力してください")
    val title: String,
    @field:Size(max = 1000, message = "descriptionは1000文字以内で入力してください")
    val description: String? = null,
    val dueDate: LocalDate? = null,
    val priority: TodoPriority = TodoPriority.MEDIUM,
    val completed: Boolean = false,
) {
    fun toEntity(): Todo {
        val todo = Todo()
        todo.title = title
        todo.description = description
        todo.dueDate = dueDate
        todo.priority = priority
        todo.completed = completed
        return todo
    }
}
```

`@Valid` がついているため、`title` が空なら自動で400エラーが返されます。

### TodoResponse（返す側）

```kotlin
data class TodoResponse(
    val id: Long,
    val title: String,
    val description: String?,
    val dueDate: LocalDate? = null,
    val priority: TodoPriority,
    val completed: Boolean,
)
```

DBエンティティをAPIレスポンス形式に変換します。`userId` は **含めていません**（セキュリティ上の理由）。

---

## 4. 認証（SecurityConfig.kt）

```kotlin
@Configuration
@EnableWebSecurity
class SecurityConfig {
    @Bean
    fun filterChain(http: HttpSecurity): SecurityFilterChain {
        http {
            authorizeHttpRequests {
                authorize(HttpMethod.OPTIONS, "/**", permitAll)
                authorize("/api/hello", permitAll)
                authorize(anyRequest, authenticated)
            }
            oauth2ResourceServer { jwt { } }
        }
        return http.build()
    }
}
```

### この設定がやること

この1つの設定で、Spring Securityが自動で以下のことをやります。

1. `Authorization: Bearer <JWT>` ヘッダーからトークンを取得
2. Cognitoの公開鍵で署名を検証
3. トークンの有効期限を確認
4. トークンの内容（`sub`クレーム等）を `Jwt` オブジェクトにパース
5. `SecurityContext` に保存

### 認可ルール


| ルール                          | 意味                 |
| ---------------------------- | ------------------ |
| `OPTIONS /** → permitAll`    | CORSプリフライトリクエストを許可 |
| `/api/hello → permitAll`     | ヘルスチェック用（認証不要）     |
| `anyRequest → authenticated` | それ以外は全てログイン必須      |


### `/api/hello` はなぜ認証不要なのか

AWSのALB（Application Load Balancer）はヘルスチェック時に **JWTトークンを送れない** ので、認証必須だとヘルスチェックが失敗してしまいます。そのため、ヘルスチェック専用のエンドポイントを認証不要としています。

---

## 5. CORS設定（WebConfig.kt）

```kotlin
@Configuration
class WebConfig(
    @Value("\${app.cors.allowed-origins}") private val allowedOrigins: String,
) : WebMvcConfigurer {
    override fun addCorsMappings(registry: CorsRegistry) {
        registry.addMapping("/api/**")
            .allowedOrigins(*allowedOrigins.split(",").map { it.trim() }.toTypedArray())
            .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
            .allowedHeaders("Content-Type", "Authorization")
            .allowCredentials(true)
            .maxAge(3600)
    }
}
```

許可するオリジンは**開発と本番で異なる**ため、環境変数から読み込んでいます。

```yaml
# application.yaml
app:
  cors:
    allowed-origins: ${CORS_ALLOWED_ORIGINS:http://localhost:3000}
```

本番ではECSのタスク定義に `CORS_ALLOWED_ORIGINS` を渡してCloudFrontのURLを許可します。

### CORSとは

**Cross-Origin Resource Sharing（オリジン間リソース共有）** の略で、「異なるドメイン（サーバー）からのリクエストを許可する仕組み」です。

なぜ必要なのか？

ブラウザには **Same-Origin Policy（同一オリジンポリシー）** というセキュリティルールがあります。あるサーバーから取得したWebページは、別のサーバーに勝手にリクエストを送ってはいけないというものです。

```
http://localhost:3000  ← フロントエンド（オリジンA）
http://localhost:8080  ← バックエンド（オリジンB）
```

ポート番号が違うだけでも「別のオリジン」とみなされます。フロントエンドがバックエンドにAPIリクエストを送る場合、**ブラウザがブロックしてしまう**ため、CORSの設定が必要になります。

### 設定の意味


| 設定                 | 意味                                              |
| ------------------ | ----------------------------------------------- |
| `allowedOrigins`   | 許可するオリジン。開発は `localhost:3000`、本番はCloudFrontのURL |
| `allowedMethods`   | GET/POST/PUT/DELETEのみ許可                         |
| `allowedHeaders`   | Content-TypeとAuthorizationヘッダーのみ許可              |
| `allowCredentials` | JWTなどの認証情報付きリクエストを許可                            |
| `maxAge`           | ブラウザがプリフライトリクエストをキャッシュする時間（秒）                   |


### つまずきポイント: 同一オリジンでも `Origin` ヘッダーは送られる

ここは実際に本番でハマったポイントです。

ブラウザは**同一オリジンのPOST/PUT/DELETEでも `Origin` ヘッダーを送ります**（GETでは送られません）。本番はCloudFrontから配信されるため、許可リストにCloudFrontのURLがないと次のようになります。

```
POST /api/todos（Origin: https://xxx.cloudfront.net）
  → CORSチェックで弾かれて403
  → 画面には「追加されない」としか見えない
```

**「ローカルでは動くのに本番で動かない」という典型的なパターンです。CORSの許可リストには本番のオリジンも必ず入れておきましょう**。

> 補足: CloudFrontの `custom_error_response` で403を200に変換していると、エラーが「成功」に見えて原因調査が非常に難しくなります。詳しくはインフラ編（3/3）で解説しています。

---

## 6. リクエストの流れ

最後に、1つのリクエストがどう処理されるかをまとめます。

![バックエンド：1リクエストの処理の流れ](https://raw.githubusercontent.com/tseno/todo-fullstack/main/docs/backend-request-flow.png)

---

## まとめ

- **Entity**: DBテーブルの構造を定義。`userId` でユーザーごとにTodoを分離
- **Repository**: メソッド名からSQLが自動生成。手動でSQLを書く必要なし
- **Service**: ビジネスロジックを担当。ユーザー隔離を強制
- **Controller**: HTTPリクエストを処理し、サービスに委譲
- **SecurityConfig**: JWT認証を自動で処理。未ログインなら401を返す
- **WebConfig**: CORS設定。許可するオリジンは環境変数で切り替える

次の記事では、フロントエンド（Next.js）の実装を解説します。

---

> **シリーズ記事**
>
> - \[1/3\] [Spring Boot × Kotlin バックエンド編](https://qiita.com/tseno/items/d2df1bdf15788d3b7011)（この記事）
> - \[2/3\] [Next.js フロントエンド編](https://qiita.com/tseno/items/ec943d5312e8c5936728)
> - \[3/3\] [Terraform × AWS インフラ編](https://qiita.com/tseno/items/4621aee6401f2ebe0d51)

