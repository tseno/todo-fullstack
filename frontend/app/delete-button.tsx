"use client";

import { useRouter } from "next/navigation";

export default function DeleteButton({ id }: { id: number }) {
    const router = useRouter();

    async function handleDelete() {
        await fetch(`http://localhost:8080/api/todos/${id}`, {
            method: "DELETE",
        });

        router.refresh();
    }
    return <button onClick={handleDelete}>削除</button>;
}