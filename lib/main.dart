import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  runApp(const MyApp());
}

class Task {
  String title;
  bool isDone;
  String priority;
  String? deadline; // format "hh:mm a" (AM/PM)

  Task({
    required this.title,
    this.isDone = false,
    this.priority = "Medium",
    this.deadline,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'isDone': isDone,
    'priority': priority,
    'deadline': deadline,
  };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    title: map['title'],
    isDone: map['isDone'],
    priority: map['priority'],
    deadline: map['deadline'],
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

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<Task>> allTasks = {};
  List<Task> tasksForSelectedDay = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });

    loadAllTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String getDateKey(DateTime date) => "${date.year}-${date.month}-${date.day}";

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
    await prefs.setString(
        getDateKey(day), jsonEncode(tasks.map((t) => t.toMap()).toList()));
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

  Future<void> updateDeadline(int index) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      final now = DateTime.now();
      final dt = DateTime(
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      final formatted = DateFormat("hh:mm a").format(dt);

      setState(() {
        tasksForSelectedDay[index].deadline = formatted;
      });
      saveTasks(_selectedDay!, tasksForSelectedDay);
    }
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

  DateTime? _parseDeadline(String? s) {
    if (s == null) return null;
    try {
      return DateFormat('hh:mm a').parse(s);
    } catch (_) {
      return null;
    }
  }

  // 🔹 Widget untuk Overdue & Completed page
  Widget buildFilteredTasksPage(
      bool Function(Task) filter,
      String emptyText, {
        IconData icon = Icons.event_note, // default
        Color iconColor = Colors.blueGrey,
      }) {
    if (allTasks.isEmpty) {
      return Center(
        child: Text(emptyText,
            style: const TextStyle(
                fontSize: 16, fontStyle: FontStyle.italic)),
      );
    }

    final filteredEntries = allTasks.entries.where((entry) {
      final tasks = entry.value.where(filter).toList();
      return tasks.isNotEmpty;
    }).toList();

    if (filteredEntries.isEmpty) {
      return Center(
        child: Text(emptyText,
            style: const TextStyle(
                fontSize: 16, fontStyle: FontStyle.italic)),
      );
    }

    return ListView(
      children: filteredEntries.expand<Widget>((entry) {
        final dateKey = entry.key;
        final tasks = entry.value.where(filter).toList();

        return <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
            child: Text(
              "Tanggal: $dateKey",
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ...tasks.map(
                (task) => ListTile(
              leading: Icon(icon, color: iconColor),
              title: Text(task.title),
              subtitle: Text(
                "Priority: ${task.priority} | Deadline: ${task.deadline ?? '-'}",
              ),
            ),
          ),
          const Divider(height: 16),
        ];
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Watcha Doin App"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Tasks"),
            Tab(text: "Summary"),
            Tab(text: "Overdue"),
            Tab(text: "Completed"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ===== TAB TASKS =====
          Column(
            children: [
              TableCalendar<Task>(
                focusedDay: _focusedDay,
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    tasksForSelectedDay =
                        allTasks[getDateKey(selectedDay)] ?? [];
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
                      color:
                      getPriorityColor(task.priority).withOpacity(0.6),
                      child: ListTile(
                        title: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Priority: ${task.priority}"),
                            if (task.deadline != null)
                              Text("Deadline: ${task.deadline}"),
                          ],
                        ),
                        leading: Checkbox(
                          value: task.isDone,
                          onChanged: (val) => toggleTask(index),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == "set_priority") {
                                  showMenu(
                                    context: context,
                                    position:
                                    const RelativeRect.fromLTRB(
                                        200, 400, 0, 0),
                                    items: const [
                                      PopupMenuItem(
                                          value: "High",
                                          child: Text("High")),
                                      PopupMenuItem(
                                          value: "Medium",
                                          child: Text("Medium")),
                                      PopupMenuItem(
                                          value: "Low",
                                          child: Text("Low")),
                                    ],
                                  ).then((val) {
                                    if (val != null) {
                                      updatePriority(index, val);
                                    }
                                  });
                                } else if (value == "set_deadline") {
                                  updateDeadline(index);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                    value: "set_priority",
                                    child: Text("Set Priority")),
                                PopupMenuItem(
                                    value: "set_deadline",
                                    child: Text("Set Deadline")),
                              ],
                              child: const Icon(Icons.more_vert),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
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

          // ===== TAB SUMMARY =====
          allTasks.isEmpty
              ? const Center(
            child: Text(
              "Belum ada task sama sekali",
              style: TextStyle(
                  fontSize: 16, fontStyle: FontStyle.italic),
            ),
          )
              : ListView(
            children: allTasks.entries.expand<Widget>((entry) {
              final dateKey = entry.key;
              final tasks = entry.value;

              if (tasks.isEmpty) return const <Widget>[];

              return <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16),
                  child: Text(
                    "Tanggal: $dateKey",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ...tasks.map(
                      (task) => ListTile(
                    leading: const Icon(Icons.event_note),
                    title: Text(task.title),
                    subtitle: Text(
                        "Priority: ${task.priority} | Deadline: ${task.deadline ?? '-'}"),
                  ),
                ),
                const Divider(height: 16),
              ];
            }).toList(),
          ),

          // ===== TAB OVERDUE =====
          buildFilteredTasksPage(
                (task) {
              final deadline = _parseDeadline(task.deadline);
              return !task.isDone &&
                  deadline != null &&
                  deadline.isBefore(DateTime.now());
            },
            "Tidak ada overdue task",
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.red,
          ),

          // ===== TAB COMPLETED =====
          buildFilteredTasksPage(
                (task) => task.isDone,
            "Tidak ada completed task",
            icon: Icons.check_circle,
            iconColor: Colors.green,
          ),

        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
        onPressed: showAddTaskDialog,
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}
