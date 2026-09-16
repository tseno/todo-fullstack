package com.example.todo_backend

import java.util.Optional
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mockito.never
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException

// サービス層のユニットテスト。リポジトリをモックして「ユーザー紐付けのロジック」を検証する
@ExtendWith(org.mockito.junit.jupiter.MockitoExtension::class)
class TodoServiceTest {

    private val todoRepository: TodoRepository = mock()
    private val todoService = TodoService(todoRepository)

    @Test
    fun `自分のTodo一覧だけを返す`() {
        val mine = Todo().apply { userId = "user-1"; title = "牛乳を買う" }
        whenever(todoRepository.findByUserId("user-1")).thenReturn(listOf(mine))

        val todos = todoService.getTodosForUser("user-1")

        assertEquals(listOf(mine), todos)
    }

    @Test
    fun `作成時にログインユーザーのsubを設定する`() {
        whenever(todoRepository.save(any<Todo>())).thenAnswer { it.getArgument<Todo>(0) }

        val todo = Todo().apply { title = "牛乳を買う" }
        val saved = todoService.createTodoForUser("user-1", todo)

        assertEquals("user-1", saved.userId)
        verify(todoRepository).save(todo)
    }

    @Test
    fun `更新時は自分のTodoの内容を差し替えuserIdとidは維持される`() {
        val existing = Todo().apply {
            id = 3
            userId = "user-1"
            title = "旧タイトル"
            priority = TodoPriority.LOW
        }
        val requested = Todo().apply {
            title = "新タイトル"
            description = "説明"
            priority = TodoPriority.HIGH
            completed = true
        }
        whenever(todoRepository.findByIdAndUserId(3L, "user-1")).thenReturn(Optional.of(existing))
        whenever(todoRepository.save(any<Todo>())).thenAnswer { it.getArgument<Todo>(0) }

        val updated = todoService.updateTodoForUser(3L, "user-1", requested)

        assertEquals(3L, updated.id)
        assertEquals("user-1", updated.userId)
        assertEquals("新タイトル", updated.title)
        assertEquals("説明", updated.description)
        assertEquals(TodoPriority.HIGH, updated.priority)
        assertEquals(true, updated.completed)
    }

    @Test
    fun `他人のTodoは更新できず404`() {
        whenever(todoRepository.findByIdAndUserId(3L, "user-2")).thenReturn(Optional.empty())

        val e = assertFailsWith<ResponseStatusException> {
            todoService.updateTodoForUser(3L, "user-2", Todo().apply { title = "新タイトル" })
        }
        assertEquals(HttpStatus.NOT_FOUND, e.statusCode)
    }

    @Test
    fun `他人のTodoは削除できず404`() {
        whenever(todoRepository.existsByIdAndUserId(3L, "user-2")).thenReturn(false)

        val e = assertFailsWith<ResponseStatusException> {
            todoService.deleteTodoForUser(3L, "user-2")
        }
        assertEquals(HttpStatus.NOT_FOUND, e.statusCode)
        verify(todoRepository, never()).deleteById(3L)
    }

    @Test
    fun `自分のTodoは削除できる`() {
        whenever(todoRepository.existsByIdAndUserId(3L, "user-1")).thenReturn(true)

        todoService.deleteTodoForUser(3L, "user-1")

        verify(todoRepository).deleteById(3L)
    }
}
