"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Todo } from "./todo";

export default function UpdateForm({ todo }: { todo: Todo }) {
    const [title, setTitle] = useState(todo.title);
    const router = useRouter();

    async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
        event.preventDefault();

        await fetch(`http://localhost:8080/api/todos/${todo.id}`, {
            method: "PUT",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ ...todo, title}),
        });

        router.refresh();
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

