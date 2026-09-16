package com.example.todo_backend

import java.util.Optional
import org.springframework.data.jpa.repository.JpaRepository

// findByUserId / findByIdAndUserId などはメソッド名からSpring Dataがクエリを自動生成する
interface TodoRepository : JpaRepository<Todo, Long> {
    fun findByUserId(userId: String): List<Todo>
    fun findByIdAndUserId(id: Long, userId: String): Optional<Todo>
    fun existsByIdAndUserId(id: Long, userId: String): Boolean
}
