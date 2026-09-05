package com.example.todo_backend

import java.time.LocalDate

// クライアントに返すレスポンス用のDTO
// Todo Entityをそのまま返すと、DBのカラム構成の変更がAPIレスポンスにそのまま影響してしまうため分離している
data class TodoResponse(
    val id: Long,
    val title: String,
    val description: String?,
    val dueDate: LocalDate?,
    val priority: String,
    val completed: Boolean,
) {
    constructor(todo: Todo) : this(
        id = todo.id,
        title = todo.title,
        description = todo.description,
        dueDate = todo.dueDate,
        priority = todo.priority,
        completed = todo.completed,
    )
}
