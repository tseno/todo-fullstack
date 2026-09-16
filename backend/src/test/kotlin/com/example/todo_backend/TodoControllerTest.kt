package com.example.todo_backend

import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.eq
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.security.oauth2.jwt.JwtDecoder
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.delete
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.springframework.test.web.servlet.put

// コントローラ層だけを起動するスライステスト。
// TodoServiceはモックに差し替え、「JWTのsubがサービスに渡されているか」を検証する
// Boot 4のWebMvcTestスライスはアプリ独自のSecurityConfigを読み込まないため明示的にimportする
// （@EnableWebSecurityがHttpSecurityや@AuthenticationPrincipal用の引数リゾルバも登録してくれる）
@WebMvcTest(TodoController::class)
@Import(SecurityConfig::class)
class TodoControllerTest(@Autowired val mockMvc: MockMvc) {

    @MockitoBean
    lateinit var todoService: TodoService

    // SecurityConfigのフィルタチェーンがJwtDecoderを要求するため、テストではモックを用意する
    @MockitoBean
    lateinit var jwtDecoder: JwtDecoder

    private fun testJwt() = jwt().jwt { it.tokenValue("dummy-token").subject("user-1") }

    @Test
    fun `GET todosはログインユーザーのsubでサービスを呼びTodo一覧を返す`() {
        val mine = Todo().apply {
            id = 1
            userId = "user-1"
            title = "牛乳を買う"
            priority = TodoPriority.MEDIUM
        }
        whenever(todoService.getTodosForUser("user-1")).thenReturn(listOf(mine))

        mockMvc.get("/api/todos") {
            with(testJwt())
        }.andExpect {
            status { isOk() }
            jsonPath("$[0].id") { value(1) }
            jsonPath("$[0].title") { value("牛乳を買う") }
            jsonPath("$[0].priority") { value("MEDIUM") }
        }
        verify(todoService).getTodosForUser("user-1")
    }

    @Test
    fun `POST todosはログインユーザーのsubを付けてTodoを作成する`() {
        whenever(todoService.createTodoForUser(any(), any())).thenAnswer { it.getArgument<Todo>(1) }

        mockMvc.post("/api/todos") {
            with(testJwt())
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"牛乳を買う","description":"2本","priority":"HIGH"}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.title") { value("牛乳を買う") }
            jsonPath("$.priority") { value("HIGH") }
        }

        val captor = argumentCaptor<Todo>()
        verify(todoService).createTodoForUser(eq("user-1"), captor.capture())
        val saved = captor.firstValue
        org.junit.jupiter.api.Assertions.assertEquals("牛乳を買う", saved.title)
        org.junit.jupiter.api.Assertions.assertEquals(TodoPriority.HIGH, saved.priority)
    }

    @Test
    fun `POST todosでpriority未指定ならMEDIUMで作成される`() {
        whenever(todoService.createTodoForUser(any(), any())).thenAnswer { it.getArgument<Todo>(1) }

        mockMvc.post("/api/todos") {
            with(testJwt())
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"掃除"}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.priority") { value("MEDIUM") }
        }
    }

    @Test
    fun `POST todosでtitleが空文字なら400`() {
        mockMvc.post("/api/todos") {
            with(testJwt())
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"","priority":"MEDIUM"}"""
        }.andExpect {
            status { isBadRequest() }
        }
    }

    @Test
    fun `POST todosで不正なpriorityなら400`() {
        mockMvc.post("/api/todos") {
            with(testJwt())
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"掃除","priority":"URGENT"}"""
        }.andExpect {
            status { isBadRequest() }
        }
    }

    @Test
    fun `PUT todosはIDとログインユーザーのsubでサービスを呼ぶ`() {
        val updated = Todo().apply {
            id = 3
            userId = "user-1"
            title = "新タイトル"
            priority = TodoPriority.HIGH
        }
        whenever(todoService.updateTodoForUser(any(), any(), any())).thenReturn(updated)

        mockMvc.put("/api/todos/3") {
            with(testJwt())
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"新タイトル","priority":"HIGH"}"""
        }.andExpect {
            status { isOk() }
            jsonPath("$.title") { value("新タイトル") }
        }
        verify(todoService).updateTodoForUser(eq(3L), eq("user-1"), any())
    }

    @Test
    fun `DELETE todosはIDとログインユーザーのsubでサービスを呼ぶ`() {
        mockMvc.delete("/api/todos/5") {
            with(testJwt())
        }.andExpect {
            status { isOk() }
        }
        verify(todoService).deleteTodoForUser(5L, "user-1")
    }
}
