"use client";

import { useState } from "react";
import { Todo } from "./todo";
import { updateTodo } from "../lib/api";

// Todoの全フィールドを編集するフォーム（更新はTodo全体を送り直す）
export default function UpdateForm({
    todo,
    onSaved,
    onCancel,
}: {
    todo: Todo;
    onSaved: () => void;
    onCancel: () => void;
}) {
    const [title, setTitle] = useState(todo.title);
    const [description, setDescription] = useState(todo.description ?? "");
    const [dueDate, setDueDate] = useState(todo.dueDate ?? "");
    const [priority, setPriority] = useState(todo.priority);

    async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
        event.preventDefault();

        await updateTodo(todo.id, {
            title,
            description: description === "" ? null : description,
            dueDate: dueDate === "" ? null : dueDate,
            priority,
            completed: todo.completed,
        });
        onSaved();
    }

    return (
        <form onSubmit={handleSubmit} className="flex flex-col gap-2 rounded-md border p-3">
            <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                required
                placeholder="タイトル"
                className="rounded border px-2 py-1 text-sm"
            />
            <input
                type="text"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="詳細（任意）"
                className="rounded border px-2 py-1 text-sm"
            />
            <div className="flex gap-2">
                <input
                    type="date"
                    value={dueDate}
                    onChange={(e) => setDueDate(e.target.value)}
                    className="rounded border px-2 py-1 text-sm"
                />
                <select
                    value={priority}
                    onChange={(e) => setPriority(e.target.value)}
                    className="rounded border px-2 py-1 text-sm"
                >
                    <option value="HIGH">高</option>
                    <option value="MEDIUM">中</option>
                    <option value="LOW">低</option>
                </select>
            </div>
            <div className="flex gap-2">
                <button type="submit" className="rounded bg-blue-600 px-3 py-1 text-sm text-white">
                    保存
                </button>
                <button type="button" onClick={onCancel} className="rounded border px-3 py-1 text-sm">
                    キャンセル
                </button>
            </div>
        </form>
    );
}
