package com.example.todo_backend

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.LocalDate

// クライアントから送られてくるリクエストボディ（POST/PUT）を受け取るためのDTO
// Todo Entityをそのまま公開しないことで、DBの都合とAPIの形を分離している
data class TodoRequest(
    @field:NotBlank(message = "titleは必須です")
    @field:Size(max = 200, message = "titleは200文字以内で入力してください")
    val title: String,
    @field:Size(max = 1000, message = "descriptionは1000文字以内で入力してください")
    val description: String? = null,
    val dueDate: LocalDate? = null,
    // 文字列以外の値が来た場合はSpringが400を返す。未指定ならMEDIUM
    val priority: TodoPriority = TodoPriority.MEDIUM,
    val completed: Boolean = false,
) {
    // 新規作成用：idを持たないTodoを組み立てる（userIdはサービス層で設定する）
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
