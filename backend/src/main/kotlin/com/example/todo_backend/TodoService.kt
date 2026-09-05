package com.example.todo_backend

import org.springframework.stereotype.Service

@Service
class TodoService(
    val todoRepository: TodoRepository
) {
    fun getTodos() = todoRepository.findAll()
    fun getTodo(id: Long) = todoRepository.findById(id)
    fun createTodo(todo: Todo) = todoRepository.save(todo)
    fun updateTodo(todo: Todo) = todoRepository.save(todo)
    fun deleteTodo(id: Long) = todoRepository.deleteById(id)
}
