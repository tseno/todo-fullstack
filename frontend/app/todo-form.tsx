"use client";

import { useState } from "react";

export default function TodoForm({ onTodoChanged }: { onTodoChanged: () => void }) {
    const [title, setTitle] = useState("");

    async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
        event.preventDefault();

        await fetch("http://localhost:8080/api/todos", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${localStorage.getItem("access_token")}`
            },
            body: JSON.stringify({ title, priority: "MEDIUM"}),
        });

        setTitle("");
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
            <button type="submit">追加</button>
            </div>
        </form>
    );
}

