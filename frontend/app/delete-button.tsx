"use client";

import { deleteTodo } from "../lib/api";

export default function DeleteButton({ id, onTodoChanged }: { id: number; onTodoChanged: () => void }) {
    async function handleDelete() {
        await deleteTodo(id);
        onTodoChanged();
    }
    return (
        <button onClick={handleDelete} className="rounded border border-red-300 px-2 py-0.5 text-sm text-red-600">
            削除
        </button>
    );
}
