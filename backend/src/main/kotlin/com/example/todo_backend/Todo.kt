package com.example.todo_backend

import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.GenerationType
import jakarta.persistence.Id
import java.time.LocalDate

@Entity
class Todo {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long = 0
    var title: String = ""
    var description: String? = null
    var dueDate: LocalDate? = null
    var priority: String = ""
    var completed: Boolean = false

}
