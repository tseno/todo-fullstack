package com.example.todo_backend

import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.whenever
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.http.MediaType
import org.springframework.security.oauth2.jwt.JwtDecoder
import org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt
import org.springframework.test.context.TestPropertySource
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.post

// CORS設定の検証。
// ブラウザは同一オリジンのPOST/PUT/DELETEでもOriginヘッダーを送るため、
// 許可リストに配信元オリジンが入っていないと403で拒否されてしまう
@WebMvcTest(TodoController::class)
@Import(SecurityConfig::class)
@TestPropertySource(
    properties = ["app.cors.allowed-origins=http://localhost:3000,https://example.cloudfront.net"],
)
class CorsConfigTest(@Autowired val mockMvc: MockMvc) {

    @MockitoBean
    lateinit var todoService: TodoService

    @MockitoBean
    lateinit var jwtDecoder: JwtDecoder

    private fun testJwt() = jwt().jwt { it.tokenValue("dummy-token").subject("user-1") }

    @Test
    fun `許可されたオリジンからのPOSTは成功する`() {
        whenever(todoService.createTodoForUser(any(), any())).thenAnswer { it.getArgument<Todo>(1) }

        mockMvc.post("/api/todos") {
            with(testJwt())
            header("Origin", "https://example.cloudfront.net")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"牛乳を買う"}"""
        }.andExpect {
            status { isOk() }
        }
    }

    @Test
    fun `許可されていないオリジンからのPOSTは403になる`() {
        mockMvc.post("/api/todos") {
            with(testJwt())
            header("Origin", "https://evil.example.com")
            contentType = MediaType.APPLICATION_JSON
            content = """{"title":"牛乳を買う"}"""
        }.andExpect {
            status { isForbidden() }
        }
    }
}
