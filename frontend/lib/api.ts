// バックエンドAPIとのやり取りをまとめたクライアント層。
// API_BASE が空文字の場合は同一オリジン（本番ではCloudFrontが /api をバックエンドへ転送する）
import { Todo } from "../app/todo";

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? "";

// Todoの作成・更新で送る内容
export interface TodoInput {
  title: string;
  description: string | null;
  dueDate: string | null;
  priority: string;
  completed: boolean;
}

function authHeaders(): HeadersInit {
  const token = localStorage.getItem("access_token");
  return {
    "Content-Type": "application/json",
    ...(token !== null ? { Authorization: `Bearer ${token}` } : {}),
  };
}

// Todo一覧を取得する。失敗（401やネットワークエラーなど）した場合はnullを返す
export async function fetchTodos(): Promise<Todo[] | null> {
  try {
    const res = await fetch(`${API_BASE}/api/todos`, { headers: authHeaders() });
    if (!res.ok) return null;
    return (await res.json()) as Todo[];
  } catch (e) {
    console.error("Todo一覧の取得に失敗しました（バックエンドが起動しているか確認してください）", e);
    return null;
  }
}

export async function createTodo(input: TodoInput): Promise<Todo | null> {
  try {
    const res = await fetch(`${API_BASE}/api/todos`, {
      method: "POST",
      headers: authHeaders(),
      body: JSON.stringify(input),
    });
    if (!res.ok) return null;
    return (await res.json()) as Todo;
  } catch (e) {
    console.error("Todoの作成に失敗しました", e);
    return null;
  }
}

export async function updateTodo(id: number, input: TodoInput): Promise<Todo | null> {
  try {
    const res = await fetch(`${API_BASE}/api/todos/${id}`, {
      method: "PUT",
      headers: authHeaders(),
      body: JSON.stringify(input),
    });
    if (!res.ok) return null;
    return (await res.json()) as Todo;
  } catch (e) {
    console.error("Todoの更新に失敗しました", e);
    return null;
  }
}

export async function deleteTodo(id: number): Promise<boolean> {
  try {
    const res = await fetch(`${API_BASE}/api/todos/${id}`, {
      method: "DELETE",
      headers: authHeaders(),
    });
    return res.ok;
  } catch (e) {
    console.error("Todoの削除に失敗しました", e);
    return false;
  }
}
