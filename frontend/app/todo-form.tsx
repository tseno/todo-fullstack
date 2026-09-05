"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function TodoForm() {
    const [title, setTitle] = useState("");
    const router = useRouter();

    async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
        event.preventDefault();

        await fetch("http://localhost:8080/api/todos", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ title, priority: "MEDIUM"}),
        });

        setTitle("");
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
            </div>
            <button type="submit">追加</button>
        </form>
    );
}

