import '../../core/models/todo_model.dart';
import '../../core/db/todo_database.dart';

class TodoService {
  final TodoDatabase _db = TodoDatabase.instance;

  Future<List<TodoItem>> getTodos() async {
    final data = await _db.getAllTasks();
    return data.map((e) => TodoItem.fromMap(e)).toList();
  }

  Future<void> addTodo(TodoItem todo) async {
    await _db.insertTask(todo.toMap());
  }

  Future<void> updateTodo(TodoItem todo) async {
    await _db.updateTask(todo.toMap());
  }

  Future<void> deleteTodo(int id) async {
    await _db.deleteTask(id);
  }
}
