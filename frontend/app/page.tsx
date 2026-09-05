import TodoForm from "./todo-form";
import DeleteButton from "./delete-button";
import UpdateForm from "./update-form";
import { Todo } from "./todo";

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
        <li key={todo.id}>
          <div>
            <UpdateForm todo={todo} />
            <DeleteButton id={todo.id} />
          </div>
        </li>
      ))}
    </ul>
    </div>
  );
}
