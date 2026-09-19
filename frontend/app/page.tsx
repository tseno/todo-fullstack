"use client";

import TodoForm from "./todo-form";
import DeleteButton from "./delete-button";
import UpdateForm from "./update-form";
import LoginButton from "./login-button";
import LogoutButton from "./logout-button";
import { Todo } from "./todo";
import { exchangeCodeForToken } from "../lib/cognito";
import { fetchTodos as apiFetchTodos, updateTodo } from "../lib/api";
import { Suspense, useCallback, useEffect, useState } from "react";
import { useSearchParams, useRouter } from "next/navigation";

export default function Page() {
    // 静的エクスポートでは useSearchParams を使うコンポーネントをSuspenseで包む必要がある
    return (
        <Suspense fallback={<main className="p-6">読み込み中...</main>}>
            <Home />
        </Suspense>
    );
}

function Home() {
    const [todos, setTodos] = useState<Todo[]>([]);
    const [isLoggedIn, setIsLoggedIn] = useState<boolean>(false);
    const router = useRouter();

    const searchParams = useSearchParams();
    const code = searchParams.get("code");
    const state = searchParams.get("state");

    const fetchTodos = useCallback(async () => {
        const data = await apiFetchTodos();
        if (data === null) {
            // APIが失敗したら未ログイン扱いにする
            setIsLoggedIn(false);
            setTodos([]);
            return;
        }
        setTodos(data);
        setIsLoggedIn(true);
    }, []);

    useEffect(() => {
        if (!code) {
            // 通常表示: トークンがあればTodo一覧を取りに行く
            if (localStorage.getItem("access_token")) {
                fetchTodos();
            }
            return;
        }
        // Cognitoからのリダイレクト: 認可コードをトークンに交換してから一覧を取得する
        async function login() {
            const token = await exchangeCodeForToken(code!, state ?? "");
            if (token !== null) {
                await fetchTodos();
            }
            // URLのクエリパラメータを削除する
            router.replace("/");
        }
        login();
    }, [code, state, fetchTodos, router]);

    const [editingTodoId, setEditingTodoId] = useState<number | null>(null);

    async function toggleCompleted(todo: Todo) {
        await updateTodo(todo.id, {
            title: todo.title,
            description: todo.description,
            dueDate: todo.dueDate,
            priority: todo.priority,
            completed: !todo.completed,
        });
        fetchTodos();
    }

    return (
        <main className="mx-auto flex max-w-xl flex-col gap-4 p-6">
            <div className="flex items-center justify-between">
                <h1 className="text-2xl font-bold">Todoアプリ</h1>
                {isLoggedIn && <LogoutButton />}
            </div>

            {!isLoggedIn && (
                <div className="rounded-md border p-6 text-center">
                    <p className="mb-4">ログインしてTodoを管理しましょう</p>
                    <LoginButton />
                </div>
            )}

            {isLoggedIn && (
                <>
                    <TodoForm onTodoChanged={fetchTodos} />
                    <ul className="flex flex-col gap-2">
                        {todos.map((todo) => (
                            <li key={todo.id} className="rounded-md border p-3">
                                {editingTodoId === todo.id ? (
                                    <UpdateForm
                                        todo={todo}
                                        onSaved={() => { setEditingTodoId(null); fetchTodos(); }}
                                        onCancel={() => setEditingTodoId(null)}
                                    />
                                ) : (
                                    <div className="flex items-start gap-2">
                                        <input
                                            type="checkbox"
                                            checked={todo.completed}
                                            onChange={() => toggleCompleted(todo)}
                                            aria-label="完了切り替え"
                                            className="mt-1"
                                        />
                                        <div className="flex-1">
                                            <p className={todo.completed ? "font-medium line-through text-gray-400" : "font-medium"}>
                                                {todo.title}
                                            </p>
                                            {todo.description && <p className="text-sm text-gray-600">{todo.description}</p>}
                                            <p className="mt-1 flex gap-3 text-xs text-gray-500">
                                                {todo.dueDate && <span>期限: {todo.dueDate}</span>}
                                                <span>優先度: {todo.priority}</span>
                                            </p>
                                        </div>
                                        <div className="flex flex-col items-end gap-1">
                                            <button
                                                type="button"
                                                onClick={() => setEditingTodoId(todo.id)}
                                                className="rounded border px-2 py-0.5 text-sm"
                                            >
                                                編集
                                            </button>
                                            <DeleteButton id={todo.id} onTodoChanged={fetchTodos} />
                                        </div>
                                    </div>
                                )}
                            </li>
                        ))}
                    </ul>
                </>
            )}
        </main>
    );
}
