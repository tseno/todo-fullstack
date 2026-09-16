package com.example.todo_backend

import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.security.core.annotation.AuthenticationPrincipal
import org.springframework.security.oauth2.jwt.Jwt
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

@RestController
@RequestMapping("/api")
class TodoController(
    val todoService: TodoService
) {

    // JWTのsubクレーム（Cognitoのユーザー識別子）を「誰のTodoか」として使う
    private fun Jwt.userId(): String = requireNotNull(this.subject) { "JWTにsubクレームがありません" }

    @GetMapping("/todos")
    fun getTodos(@AuthenticationPrincipal jwt: Jwt): List<TodoResponse> =
        todoService.getTodosForUser(jwt.userId()).map { TodoResponse(it) }.toList()

    @GetMapping("/todos/{id}")
    fun getTodo(@PathVariable id: Long, @AuthenticationPrincipal jwt: Jwt): TodoResponse =
        todoService.getTodoForUser(id, jwt.userId())
            .map { TodoResponse(it) }
            .orElseThrow { ResponseStatusException(HttpStatus.NOT_FOUND, "Todo not found: $id") }

    @PostMapping("/todos")
    fun createTodo(@AuthenticationPrincipal jwt: Jwt, @Valid @RequestBody todoRequest: TodoRequest): TodoResponse =
        TodoResponse(todoService.createTodoForUser(jwt.userId(), todoRequest.toEntity()))

    @PutMapping("/todos/{id}")
    fun updateTodo(
        @PathVariable id: Long,
        @AuthenticationPrincipal jwt: Jwt,
        @Valid @RequestBody todoRequest: TodoRequest
    ): TodoResponse =
        TodoResponse(todoService.updateTodoForUser(id, jwt.userId(), todoRequest.toEntity()))

    @DeleteMapping("/todos/{id}")
    fun deleteTodo(@PathVariable id: Long, @AuthenticationPrincipal jwt: Jwt) {
        todoService.deleteTodoForUser(id, jwt.userId())
    }
}
