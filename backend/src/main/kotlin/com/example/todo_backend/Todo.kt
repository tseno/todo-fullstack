package com.example.todo_backend

import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import java.time.LocalDate

// Todoの優先度。DBには文字列(LOW/MEDIUM/HIGH)として保存される
enum class TodoPriority {
    LOW,
    MEDIUM,
    HIGH,
}

@Entity
class Todo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long = 0

    // このTodoを所有するユーザーのID（Cognitoのsubクレーム）
    // 全ユーザーでTodoを共有しないよう、必ずログインユーザーと紐付ける
    var userId: String = ""
    var title: String = ""
    var description: String? = null
    var dueDate: LocalDate? = null

    @Enumerated(EnumType.STRING)
    var priority: TodoPriority = TodoPriority.MEDIUM
    var completed: Boolean = false

}
