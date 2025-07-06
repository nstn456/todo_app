import 'package:flutter/material.dart'; 
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'login_page.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  await Hive.initFlutter();
  await Hive.openBox('tasks');
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      initialRoute: user == null ? '/' : '/home',
      routes: {
        '/': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Box _taskBox = Hive.box('tasks');

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  DateTime? _selectedDate;
  String _selectedPriority = 'Low';
  String _searchQuery = '';

  void _addTask(String title, String desc) {
    final task = {
      'title': title,
      'desc': desc,
      'isDone': false,
      'priority': _selectedPriority,
      'dueDate': _selectedDate?.toIso8601String(),
    };
    _taskBox.add(task);
    Navigator.of(context).pop();
    _titleController.clear();
    _descController.clear();
    _selectedDate = null;
    _selectedPriority = 'Low';
    setState(() {});
  }

  void _toggleComplete(int index) {
    final task = _taskBox.getAt(index) as Map;
    task['isDone'] = !(task['isDone'] ?? false);
    _taskBox.putAt(index, task);
    setState(() {});
  }

  void _deleteTask(int index) {
    _taskBox.deleteAt(index);
    setState(() {});
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add New Task"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task Title'),
            ),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Task Description'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedPriority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: ['Low', 'Medium', 'High']
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPriority = value!;
                });
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    _selectedDate = pickedDate;
                  });
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _selectedDate == null
                    ? 'Select Due Date'
                    : 'Due: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _addTask(_titleController.text, _descController.text);
            },
            child: const Text("Add"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user?.displayName ?? 'My Todo App'}'),
        actions: [
          if (user?.photoURL != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundImage: NetworkImage(user!.photoURL!),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by Title',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: _taskBox.isEmpty
                ? const Center(child: Text("No tasks yet!"))
                : ListView.builder(
                    itemCount: _taskBox.length,
                    itemBuilder: (_, index) {
                      final task = _taskBox.getAt(index) as Map;

                      // Filter by search
                      if (_searchQuery.isNotEmpty &&
                          !task['title']
                              .toString()
                              .toLowerCase()
                              .contains(_searchQuery)) {
                        return const SizedBox.shrink();
                      }

                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          leading: Checkbox(
                            value: task['isDone'] ?? false,
                            onChanged: (_) => _toggleComplete(index),
                          ),
                          title: Text(
                            task['title'],
                            style: TextStyle(
                              decoration: (task['isDone'] ?? false)
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task['desc']),
                              Text(
                                  'Priority: ${task['priority'] ?? 'Low'}'),
                              if (task['dueDate'] != null)
                                Text(
                                  'Due: ${DateTime.parse(task['dueDate']).day}/${DateTime.parse(task['dueDate']).month}/${DateTime.parse(task['dueDate']).year}',
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon:
                                const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTask(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
