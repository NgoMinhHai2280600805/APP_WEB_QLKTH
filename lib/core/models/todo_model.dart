class TodoItem {
  final int? id;
  final String title;
  final String description;
  final String? imagePath;
  final bool isCompleted;

  TodoItem({
    this.id,
    required this.title,
    required this.description,
    this.imagePath,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imagePath': imagePath,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory TodoItem.fromMap(Map<String, dynamic> map) {
    return TodoItem(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      imagePath: map['imagePath'] as String?,
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
    );
  }
}
