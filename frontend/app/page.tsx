"use client"

import TodoForm from "./todo-form";
import DeleteButton from "./delete-button";
import UpdateForm from "./update-form";
import LoginButton from "./login-button";
import { useEffect, useState } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { Todo } from "./todo";

export default function Home() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const router = useRouter();

  const searchParams = useSearchParams();
  const code = searchParams.get("code");

  async function fetchTodos() {
    const res = await fetch("http://localhost:8080/api/todos", {
      headers: {
        "Authorization": `Bearer ${localStorage.getItem("access_token")}`
      }
    });
    const data = await res.json();
    setTodos(data);
  }

  useEffect(() => {
    if (!code) {
      fetchTodos();
      return;
    }
    async function fetchToken(code: string) {
      const resToken = await fetch("https://todo-fullstack-201302613838.auth.ap-northeast-1.amazoncognito.com/oauth2/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "authorization_code",
          client_id: "558ic139gocj8dbv2ba7b0rept",
          code: code, // URLから取得したもの
          redirect_uri: "http://localhost:3000",
        }),
      });
      const dataToken = await resToken.json();
      localStorage.setItem("access_token", dataToken.access_token);
      fetchTodos();
    }
    fetchToken(code);
    router.replace("/");
  }, []);

  return (
    <div>
      <LoginButton />
      <TodoForm onTodoChanged={fetchTodos} />
      <ul>
        {todos.map((todo) => (
          <li key={todo.id}>
            <div>
              <UpdateForm todo={todo} onTodoChanged={fetchTodos} />
              <DeleteButton id={todo.id} onTodoChanged={fetchTodos} />
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
