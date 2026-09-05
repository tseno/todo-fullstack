package com.example.todo_backend

import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

@RestController
@RequestMapping("/api")
class TodoController(
    val todoService: TodoService
) {

    @GetMapping("/todos")
    fun getTodos(): List<TodoResponse> =
        todoService.getTodos().map { TodoResponse(it) }.toList()

    @GetMapping("/todos/{id}")
    fun getTodo(@PathVariable id: Long): TodoResponse =
        todoService.getTodo(id)
            .map { TodoResponse(it) }
            .orElseThrow{ ResponseStatusException( HttpStatus.NOT_FOUND, "Todo not found: $id") }

    @PostMapping("/todos")
    fun createTodo(@RequestBody todoRequest: TodoRequest): TodoResponse =
        TodoResponse(todoService.createTodo(todoRequest.toEntity()))

    @PutMapping("/todos/{id}")
    fun updateTodo(@PathVariable id: Long, @RequestBody todoRequest: TodoRequest): TodoResponse =
        TodoResponse(todoService.updateTodo(todoRequest.toEntity(id)))

    @DeleteMapping("/todos/{id}")
    fun deleteTodo(@PathVariable id: Long) {
        todoService.deleteTodo(id)
    }
}
