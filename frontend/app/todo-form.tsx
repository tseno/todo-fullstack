"use client";

import { useState } from "react";
import { createTodo } from "../lib/api";

// 新しいTodoを作成するフォーム
export default function TodoForm({ onTodoChanged }: { onTodoChanged: () => void }) {
    const [title, setTitle] = useState("");
    const [description, setDescription] = useState("");
    const [dueDate, setDueDate] = useState("");
    const [priority, setPriority] = useState("MEDIUM");

    async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
        event.preventDefault();

        await createTodo({
            title,
            description: description === "" ? null : description,
            dueDate: dueDate === "" ? null : dueDate,
            priority,
            completed: false,
        });

        setTitle("");
        setDescription("");
        setDueDate("");
        setPriority("MEDIUM");
        onTodoChanged();
    }

    return (
        <form onSubmit={handleSubmit} className="flex flex-col gap-2 rounded-md border p-3">
            <div className="flex gap-2">
                <input
                    type="text"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    placeholder="やることを入力"
                    required
                    className="flex-1 rounded border px-2 py-1"
                />
                <button type="submit" className="rounded bg-blue-600 px-3 py-1 text-white">
                    追加
                </button>
            </div>
            <div className="flex gap-2 text-sm">
                <input
                    type="text"
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="詳細（任意）"
                    className="flex-1 rounded border px-2 py-1"
                />
                <input
                    type="date"
                    value={dueDate}
                    onChange={(e) => setDueDate(e.target.value)}
                    className="rounded border px-2 py-1"
                />
                <select value={priority} onChange={(e) => setPriority(e.target.value)} className="rounded border px-2 py-1">
                    <option value="HIGH">高</option>
                    <option value="MEDIUM">中</option>
                    <option value="LOW">低</option>
                </select>
            </div>
        </form>
    );
}
