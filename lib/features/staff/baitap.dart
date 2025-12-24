import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/todo_model.dart';
import '../../core/services/todo_service.dart';

class BaiTapScreen extends StatefulWidget {
  const BaiTapScreen({super.key});

  @override
  State<BaiTapScreen> createState() => _BaiTapScreenState();
}

class _BaiTapScreenState extends State<BaiTapScreen> {
  List<TodoItem> _tasks = [];
  final ImagePicker _picker = ImagePicker();
  final TodoService _todoService = TodoService();

  // Lưu id các task đang được chọn
  Set<int> _selectedTaskIds = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final data = await _todoService.getTodos();
    // Sắp xếp: các task chưa hoàn thành lên đầu, hoàn thành xuống cuối
    data.sort((a, b) {
      if (a.isCompleted && !b.isCompleted) return 1;
      if (!a.isCompleted && b.isCompleted) return -1;
      return 0;
    });

    setState(() {
      _tasks = data;
      _selectedTaskIds.clear(); // reset chọn khi load lại
    });
  }

  void _addTaskDialog() {
    String title = '';
    String description = '';
    String? selectedImage;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Thêm công việc mới"),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Tên công việc'),
                  onChanged: (val) => title = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                  onChanged: (val) => description = val,
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    final image = await _picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      setState(() => selectedImage = image.path);
                    }
                  },
                  icon: const Icon(Icons.photo),
                  label: const Text("Chọn ảnh đính kèm"),
                ),
                if (selectedImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Image.file(File(selectedImage!), height: 100),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Hủy"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Thêm"),
            onPressed: () async {
              if (title.trim().isNotEmpty) {
                final newTask = TodoItem(
                  title: title,
                  description: description,
                  imagePath: selectedImage,
                  isCompleted: false,
                );
                await _todoService.addTodo(newTask);
                Navigator.pop(context);
                _loadTasks();
              }
            },
          ),
        ],
      ),
    );
  }

  // Đánh dấu hoàn thành các task đã chọn
  Future<void> _completeSelectedTasks() async {
    for (final id in _selectedTaskIds) {
      final task = _tasks.firstWhere((t) => t.id == id);
      if (!task.isCompleted) {
        final updatedTask = TodoItem(
          id: task.id,
          title: task.title,
          description: task.description,
          imagePath: task.imagePath,
          isCompleted: true,
        );
        await _todoService.updateTodo(updatedTask);
      }
    }
    await _loadTasks();
  }

  Future<void> _toggleTaskSelection(int id, bool? selected) async {
    setState(() {
      if (selected == true) {
        _selectedTaskIds.add(id);
      } else {
        _selectedTaskIds.remove(id);
      }
    });
  }

  Future<void> _deleteTask(int index) async {
    final task = _tasks[index];
    await _todoService.deleteTodo(task.id!);
    _loadTasks();
  }

  // Khi bấm vào task, chuyển sang màn chi tiết
  void _openTaskDetail(TodoItem task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TodoDetailScreen(task: task, isEdit: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("To-Do List"),
        actions: [
          if (_selectedTaskIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: "Hoàn thành các công việc đã chọn",
              onPressed: _completeSelectedTasks,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTaskDialog,
        child: const Icon(Icons.add),
      ),
      body: _tasks.isEmpty
          ? const Center(child: Text("Chưa có công việc nào"))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                final isSelected = _selectedTaskIds.contains(task.id);

                return Card(
                  color: task.isCompleted
                      ? Colors.lightBlue[100]
                      : Colors.white,
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (selected) =>
                          _toggleTaskSelection(task.id!, selected),
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted ? Colors.blue : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      task.description,
                      style: TextStyle(
                        color: task.isCompleted ? Colors.blue : Colors.black,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (task.imagePath != null &&
                            File(task.imagePath!).existsSync())
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Image.file(
                              File(task.imagePath!),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          const Icon(Icons.task),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteTask(index),
                        ),
                      ],
                    ),
                    onTap: () => _openTaskDetail(task),
                  ),
                );
              },
            ),
    );
  }
}

// Màn hình chi tiết công việc (bao gồm sửa công việc)
class TodoDetailScreen extends StatefulWidget {
  final TodoItem task;
  final bool isEdit;

  const TodoDetailScreen({super.key, required this.task, this.isEdit = false});

  @override
  _TodoDetailScreenState createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(
      text: widget.task.description,
    );
    _imagePath = widget.task.imagePath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveTask() async {
    final updatedTask = TodoItem(
      id: widget.task.id,
      title: _titleController.text,
      description: _descriptionController.text,
      imagePath: _imagePath,
      isCompleted: widget.task.isCompleted,
    );

    await TodoService().updateTodo(updatedTask);

    // Quay lại màn hình chính sau khi lưu
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? "Sửa công việc" : "Chi tiết công việc"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tên công việc'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              const SizedBox(height: 16),
              if (_imagePath != null) Image.file(File(_imagePath!)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final image = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    setState(() {
                      _imagePath = image.path;
                    });
                  }
                },
                icon: const Icon(Icons.photo),
                label: const Text("Chọn ảnh mới"),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveTask,
                child: const Text("Lưu công việc"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
