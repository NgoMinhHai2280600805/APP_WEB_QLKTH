import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class TodoDatabase {
  static final TodoDatabase instance = TodoDatabase._init();

  static Database? _database;

  TodoDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('todo.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        imagePath TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // CRUD operations
  Future<int> insertTask(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('tasks', row);
  }

  Future<List<Map<String, dynamic>>> getAllTasks() async {
    final db = await instance.database;
    return await db.query('tasks', orderBy: 'isCompleted ASC, id DESC');
  }

  Future<int> updateTask(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.update(
      'tasks',
      row,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
