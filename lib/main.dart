import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  runApp(const MyApp());
}

class Task {
  String title;
  bool isDone;
  String priority;

  Task({required this.title, this.isDone = false, this.priority = "Medium"});

  Map<String, dynamic> toMap() => {
    'title': title,
    'isDone': isDone,
    'priority': priority,
  };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    title: map['title'],
    isDone: map['isDone'],
    priority: map['priority'],
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Watcha Doin App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CalendarScreen(),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<Task>> allTasks = {};
  List<Task> tasksForSelectedDay = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    loadAllTasks();
  }

  String getDateKey(DateTime date) =>
      "${date.year}-${date.month}-${date.day}";

  Future<void> loadAllTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    Map<String, List<Task>> temp = {};
    for (var key in keys) {
      final data = prefs.getString(key);
      if (data != null) {
        List decoded = jsonDecode(data);
        temp[key] = decoded.map((e) => Task.fromMap(e)).toList();
      }
    }

    setState(() {
      allTasks = temp;
      tasksForSelectedDay = allTasks[getDateKey(_selectedDay!)] ?? [];
    });
  }

  Future<void> saveTasks(DateTime day, List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(getDateKey(day),
        jsonEncode(tasks.map((t) => t.toMap()).toList()));
    await loadAllTasks();
  }

  void addTask(String title) {
    setState(() {
      tasksForSelectedDay.add(Task(title: title));
    });
    saveTasks(_selectedDay!, tasksForSelectedDay);
  }

  void toggleTask(int index) {
    setState(() {
      tasksForSelectedDay[index].isDone = !tasksForSelectedDay[index].isDone;
    });
    saveTasks(_selectedDay!, tasksForSelectedDay);
  }

  void deleteTask(int index) {
    setState(() {
      tasksForSelectedDay.removeAt(index);
    });
    saveTasks(_selectedDay!, tasksForSelectedDay);
  }

  void updatePriority(int index, String priority) {
    setState(() {
      tasksForSelectedDay[index].priority = priority;
    });
    saveTasks(_selectedDay!, tasksForSelectedDay);
  }

  Color getPriorityColor(String priority) {
    switch (priority) {
      case "High":
        return Colors.red.shade200;
      case "Medium":
        return Colors.orange.shade200;
      case "Low":
        return Colors.green.shade200;
      default:
        return Colors.grey.shade200;
    }
  }

  Future<void> showAddTaskDialog() async {
    TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Task"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter task"),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  addTask(controller.text);
                }
                Navigator.pop(context);
              },
              child: const Text("Add"),
            )
          ],
        );
      },
    );
  }

  Future<void> confirmDelete(int index) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Konfirmasi"),
          content: const Text("Yakin mau hapus task ini?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                deleteTask(index);
                Navigator.pop(context);
              },
              child: const Text("Hapus"),
            ),
          ],
        );
      },
    );
  }

  List<Task> getEventsForDay(DateTime day) {
    return allTasks[getDateKey(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Watcha Doin App")),
      body: Column(
        children: [
          // Calendar tetap fixed
          TableCalendar<Task>(
            focusedDay: _focusedDay,
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                tasksForSelectedDay = allTasks[getDateKey(selectedDay)] ?? [];
              });
            },
            eventLoader: getEventsForDay,
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // LIST TASK dibungkus Expanded biar fleksibel scroll
          Expanded(
            child: tasksForSelectedDay.isEmpty
                ? const Center(
              child: Text(
                "Belum ada task untuk hari ini",
                style: TextStyle(
                    fontSize: 16, fontStyle: FontStyle.italic),
              ),
            )
                : ListView.builder(
              itemCount: tasksForSelectedDay.length,
              itemBuilder: (context, index) {
                final task = tasksForSelectedDay[index];
                return Card(
                  color: getPriorityColor(task.priority).withOpacity(0.6),
                  child: ListTile(
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Text("Priority: ${task.priority}"),
                    leading: Checkbox(
                      value: task.isDone,
                      onChanged: (val) => toggleTask(index),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          onSelected: (value) =>
                              updatePriority(index, value),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: "High", child: Text("High")),
                            const PopupMenuItem(
                                value: "Medium", child: Text("Medium")),
                            const PopupMenuItem(
                                value: "Low", child: Text("Low")),
                          ],
                          child: const Icon(Icons.more_vert),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => confirmDelete(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
