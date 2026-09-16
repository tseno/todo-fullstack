package com.example.todo_backend

import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service
import org.springframework.web.server.ResponseStatusException

// すべての操作を「ログインユーザー自身のTodo」に限定するのがこのサービスの責務
// userId（Cognitoのsub）が一致しないTodoは、存在しても404として扱う
@Service
class TodoService(
    val todoRepository: TodoRepository
) {
    fun getTodosForUser(userId: String) = todoRepository.findByUserId(userId)

    fun getTodoForUser(id: Long, userId: String) = todoRepository.findByIdAndUserId(id, userId)

    fun createTodoForUser(userId: String, todo: Todo): Todo {
        todo.userId = userId
        return todoRepository.save(todo)
    }

    fun updateTodoForUser(id: Long, userId: String, todo: Todo): Todo =
        todoRepository.findByIdAndUserId(id, userId)
            .map { existing ->
                // 既存エンティティを差し替える形で更新する（idとuserIdは変更しない）
                existing.title = todo.title
                existing.description = todo.description
                existing.dueDate = todo.dueDate
                existing.priority = todo.priority
                existing.completed = todo.completed
                todoRepository.save(existing)
            }
            .orElseThrow { ResponseStatusException(HttpStatus.NOT_FOUND, "Todo not found: $id") }

    fun deleteTodoForUser(id: Long, userId: String) {
        if (!todoRepository.existsByIdAndUserId(id, userId)) {
            throw ResponseStatusException(HttpStatus.NOT_FOUND, "Todo not found: $id")
        }
        todoRepository.deleteById(id)
    }
}
