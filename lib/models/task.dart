class Task {
  String title;
  bool isDone;

  Task({required this.title, this.isDone = false});

  // Convert to Map untuk simpan ke SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isDone': isDone,
    };
  }

  // Convert dari Map ke Task
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      title: json['title'],
      isDone: json['isDone'],
    );
  }
}
