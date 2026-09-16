"use client";

import { useState } from "react";
import { Todo } from "./todo";
import { updateTodo } from "../lib/api";

// Todoのタイトルを編集するフォーム（更新はTodo全体を送り直す）
export default function UpdateForm({ todo, onTodoChanged }: { todo: Todo; onTodoChanged: () => void }) {
    const [title, setTitle] = useState(todo.title);

    async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
        event.preventDefault();

        await updateTodo(todo.id, {
            title,
            description: todo.description,
            dueDate: todo.dueDate,
            priority: todo.priority,
            completed: todo.completed,
        });
        onTodoChanged();
    }

    return (
        <form onSubmit={handleSubmit} className="flex gap-1">
            <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                aria-label="タイトルを編集"
                className="w-32 rounded border px-1 py-0.5 text-sm"
            />
            <button type="submit" className="rounded border px-2 py-0.5 text-sm">
                保存
            </button>
        </form>
    );
}
