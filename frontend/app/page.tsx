import TodoForm from "./todo-form";
import DeleteButton from "./delete-button";

interface Todo {
  id: number;
  title: string;
  description: string | null;
  dueDate: string | null;
  priority: string;
  completed: boolean;
}

async function getTodos(): Promise<Todo[]> {
  const res = await fetch("http://localhost:8080/api/todos", {
    cache: "no-store",
  });
  return res.json();
}

export default async function Home() {
  const todos = await getTodos();

  return (
    <div>
      <TodoForm />
    <ul>
      {todos.map((todo) => (
        <li key={todo.id}>{todo.title}
          <DeleteButton id={todo.id} />
        </li>
      ))}
    </ul>
    </div>
  );
}
