import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../services/api_service.dart';
import '../../features/face_auth/face_storage.dart';
import '../../widgets/custom_app_bar.dart';

class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({super.key});

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  List<dynamic> _tasks = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadTasks();
  }

  Future<void> _initNotifications() async {
    tz_data.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _notifications.initialize(settings);
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId != null) {
        final tasks =
            await _apiService.getElderTasks(elderId, date: _selectedDate);
        setState(() => _tasks = tasks);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des tâches: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleNotification(dynamic task) async {
    if (task['reminderEnabled'] != true || task['isCompleted'] == true) return;

    final taskTime = task['time'] as String; // HH:mm
    final taskDate = DateTime.parse(task['date']);

    final parts = taskTime.split(':');
    final scheduledDate = DateTime(
      taskDate.year,
      taskDate.month,
      taskDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    if (scheduledDate.isBefore(DateTime.now())) return;

    final id = task['_id'].hashCode;

    await _notifications.zonedSchedule(
      id,
      'Rappel de tâche',
      task['title'],
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_tasks_channel',
          'Tâches quotidiennes',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _addTask() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nouvelle tâche',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  style: const TextStyle(fontSize: 22),
                  decoration: InputDecoration(
                    labelText: 'Quoi faire ?',
                    labelStyle: const TextStyle(fontSize: 20),
                    hintText: 'Ex: Faire ma marche',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: descController,
                  style: const TextStyle(fontSize: 20),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Plus de détails (Optionnel)',
                    labelStyle: const TextStyle(fontSize: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('À quelle heure ?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Hour Column
                    Column(
                      children: [
                        _buildTimeButton(Icons.add, () {
                          setModalState(() {
                            selectedTime = TimeOfDay(
                              hour: (selectedTime.hour + 1) % 24,
                              minute: selectedTime.minute,
                            );
                          });
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            selectedTime.hour.toString().padLeft(2, '0'),
                            style: const TextStyle(
                                fontSize: 50, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildTimeButton(Icons.remove, () {
                          setModalState(() {
                            selectedTime = TimeOfDay(
                              hour: (selectedTime.hour - 1 + 24) % 24,
                              minute: selectedTime.minute,
                            );
                          });
                        }),
                        const Text('Heures', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                    const Text(':',
                        style: TextStyle(
                            fontSize: 50, fontWeight: FontWeight.bold)),
                    // Minute Column
                    Column(
                      children: [
                        _buildTimeButton(Icons.add, () {
                          setModalState(() {
                            selectedTime = TimeOfDay(
                              hour: selectedTime.hour,
                              minute: (selectedTime.minute + 5) % 60,
                            );
                          });
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            selectedTime.minute.toString().padLeft(2, '0'),
                            style: const TextStyle(
                                fontSize: 50, fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildTimeButton(Icons.remove, () {
                          setModalState(() {
                            selectedTime = TimeOfDay(
                              hour: selectedTime.hour,
                              minute: (selectedTime.minute - 5 + 60) % 60,
                            );
                          });
                        }),
                        const Text('Minutes', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty) return;

                    final elderId = InMemoryFaceStorage().getElderId();
                    if (elderId != null) {
                      final timeStr =
                          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

                      final result = await _apiService.addTask(
                        elderId: elderId,
                        title: titleController.text,
                        description: descController.text,
                        time: timeStr,
                        date: _selectedDate,
                      );

                      if (result['success'] == true) {
                        _scheduleNotification(result['task']);
                        if (mounted) Navigator.pop(context);
                        _loadTasks();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text(
                    'ENREGISTRER LA TÂCHE',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleTaskStatus(dynamic task) async {
    try {
      final result = await _apiService.updateTask(task['_id'], {
        'isCompleted': !task['isCompleted'],
      });
      if (result['success'] == true) {
        if (result['task']['isCompleted'] == true) {
          await _notifications.cancel(task['_id'].hashCode);
        } else {
          _scheduleNotification(result['task']);
        }
        _loadTasks();
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  Future<void> _deleteTask(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette tâche ?', style: TextStyle(fontSize: 22)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NON', style: TextStyle(fontSize: 20)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('OUI, SUPPRIMER', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteTask(id);
        await _notifications.cancel(id.hashCode);
        _loadTasks();
      } catch (e) {
        debugPrint('Error deleting task: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Mes Tâches', showBackButton: true),
      body: Column(
        children: [
          _buildCalendarStrip(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined,
                                size: 100, color: Colors.grey[400]),
                            const SizedBox(height: 20),
                            Text(
                              'Aucune tâche pour aujourd\'hui',
                              style: TextStyle(
                                  fontSize: 22, color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          return _buildTaskItem(task);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: SizedBox(
        width: 80,
        height: 80,
        child: FloatingActionButton(
          onPressed: _addTask,
          backgroundColor: Colors.blue[600],
          elevation: 8,
          child: const Icon(Icons.add, size: 45, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildTimeButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 70,
      height: 70,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.blue[50],
          foregroundColor: Colors.blue[800],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 2,
        ),
        child: Icon(icon, size: 40),
      ),
    );
  }

  Widget _buildCalendarStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.blue[50],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 35),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
              _loadTasks();
            },
          ),
          Column(
            children: [
              Text(
                DateFormat('EEEE', 'fr_FR').format(_selectedDate).toUpperCase(),
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.blue[800],
                    fontWeight: FontWeight.w500),
              ),
              Text(
                DateFormat('d MMMM', 'fr_FR').format(_selectedDate),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 35),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
              _loadTasks();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(dynamic task) {
    final bool isCompleted = task['isCompleted'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: InkWell(
        onTap: () => _toggleTaskStatus(task),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle : Icons.circle_outlined,
                color: isCompleted ? Colors.green : Colors.grey,
                size: 50,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['title'],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? Colors.grey : Colors.black87,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 24, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          task['time'],
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red, size: 35),
                onPressed: () => _deleteTask(task['_id']),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
