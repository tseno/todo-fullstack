package com.example.todo_backend

import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest
import org.springframework.context.annotation.Import
import org.springframework.security.oauth2.jwt.JwtDecoder
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get

// ヘルスチェック用エンドポイントのテスト。
// ALBのヘルスチェックはJWTを持てないため、/api/hello は認証なしで200を返す必要がある
@WebMvcTest(HelloController::class)
@Import(SecurityConfig::class)
class HelloControllerTest(@Autowired val mockMvc: MockMvc) {

    @MockitoBean
    lateinit var jwtDecoder: JwtDecoder

    @Test
    fun `helloは認証なしで200を返す`() {
        mockMvc.get("/api/hello").andExpect {
            status { isOk() }
            jsonPath("$.message") { value("Hello, World") }
        }
    }
}
