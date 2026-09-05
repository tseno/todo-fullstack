package com.example.todo_backend

import java.time.LocalDate

// クライアントから送られてくるリクエストボディ（POST/PUT）を受け取るためのDTO
// Todo Entityをそのまま公開しないことで、DBの都合とAPIの形を分離している
data class TodoRequest(
    val title: String,
    val description: String? = null,
    val dueDate: LocalDate? = null,
    val priority: String,
    val completed: Boolean = false,
) {
    // 新規作成用：idを持たないTodoを組み立てる
    fun toEntity(): Todo {
        val todo = Todo()
        todo.title = title
        todo.description = description
        todo.dueDate = dueDate
        todo.priority = priority
        todo.completed = completed
        return todo
    }

    // 更新用：既存のidを指定してTodoを組み立てる
    fun toEntity(id: Long): Todo {
        val todo = toEntity()
        todo.id = id
        return todo
    }
}
