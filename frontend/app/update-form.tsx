"use client";

import { useState } from "react";
import { Todo } from "./todo";

export default function UpdateForm({ todo, onTodoChanged }: { todo: Todo; onTodoChanged: () => void }) {
    const [title, setTitle] = useState(todo.title);

    async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
        event.preventDefault();

        await fetch(`http://localhost:8080/api/todos/${todo.id}`, {
            method: "PUT",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${localStorage.getItem("access_token")}`
            },
            body: JSON.stringify({ ...todo, title}),
        });
        onTodoChanged();
    }

    return (
        <form onSubmit={handleSubmit}>
            <div>
                <input
                    type="text"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    placeholder="やることを入力"
                />
            <button type="submit">更新</button>
            </div>
        </form>
    );
}

