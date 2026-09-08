"use client";

export default function DeleteButton({ id, onTodoChanged }: { id: number; onTodoChanged: () => void }) {

    async function handleDelete() {
        await fetch(`http://localhost:8080/api/todos/${id}`, {
            method: "DELETE",
            headers: {
                "Authorization": `Bearer ${localStorage.getItem("access_token")}`
            }
        });
        onTodoChanged();
    }
    return <button onClick={handleDelete}>削除</button>;
}