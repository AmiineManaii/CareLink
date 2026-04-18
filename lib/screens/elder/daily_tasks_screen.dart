import 'package:care_link/utils/face_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import '../../services/api_service.dart';
import '../../widgets/common/custom_app_bar.dart';
import 'dart:async';

class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({super.key});

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  final ApiService _apiService = ApiService();

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
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final elderId = InMemoryFaceStorage().getElderId();
      if (elderId != null) {
        final tasks = await _apiService.getElderTasks(
          elderId,
          date: _selectedDate,
        );
        setState(() => _tasks = tasks);

        for (var task in tasks) {
          _scheduleNotification(task);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du chargement des tâches'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleNotification(dynamic task) async {
    if (task['reminderEnabled'] != true || task['isCompleted'] == true) return;

    final taskTime = task['time'] as String;
    final taskDate = DateTime.parse(task['date']);

    final parts = taskTime.split(':');
    DateTime scheduledDate = DateTime(
      taskDate.year,
      taskDate.month,
      taskDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    final DateTime actualTaskTime = scheduledDate;
    final DateTime warningTime = actualTaskTime.subtract(
      const Duration(minutes: 15),
    );

    DateTime finalScheduledTime = warningTime;
    String label = "${task['title']} (dans 15 min)";

    if (warningTime.isBefore(DateTime.now())) {
      // If 15 min before is past, but task time is future or now
      if (actualTaskTime.isAfter(
        DateTime.now().subtract(const Duration(seconds: 59)),
      )) {
        // Schedule for 2 seconds from now for immediate trigger
        finalScheduledTime = DateTime.now().add(const Duration(seconds: 2));
        label = "${task['title']} (Maintenant)";
      } else {
        return; // Already past
      }
    }

    final id = task['_id'].toString();
    const channel = MethodChannel('fall_channel');
    await channel.invokeMethod('scheduleTask', {
      'id': id,
      'title': label,
      'description': task['description'] ?? '',
      'timestamp': finalScheduledTime.millisecondsSinceEpoch,
    });
  }

  // ====================== CONFIRMATION SIMPLIFIÉE POUR PERSONNES ÂGÉES ======================
  Future<void> _toggleTaskStatus(dynamic task) async {
    if (task['isCompleted'] == true) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: const Text(
          'Est-ce terminé ?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Voulez-vous marquer "${task['title']}" comme terminé ?',
          style: const TextStyle(fontSize: 22, height: 1.4),
          textAlign: TextAlign.center,
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'NON',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'OUI',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Le reste du code reste le même...
    try {
      final result = await _apiService.updateTask(task['_id'], {
        'isCompleted': true,
      });

      if (result['success'] == true) {
        const channel = MethodChannel('fall_channel');
        await channel.invokeMethod('cancelTask', {
          'id': task['_id'].toString(),
        });

        _loadTasks();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tâche terminée ✓'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  // ====================== AJOUT DE TÂCHE (Design amélioré + Fix Time Picker) ======================
  Future<void> _addTask() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final timeNotifier = ValueNotifier<TimeOfDay>(TimeOfDay.now());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 32,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nouvelle tâche',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),

                  TextField(
                    controller: titleController,
                    style: const TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                      labelText: 'Titre de la tâche',
                      hintText: 'Ex: Prendre mes médicaments',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: descController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Description (optionnel)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'Heure de la tâche',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  // Time Picker fixe
                  ValueListenableBuilder<TimeOfDay>(
                    valueListenable: timeNotifier,
                    builder: (context, selectedTime, child) {
                      return _buildModernTimePicker(selectedTime, (newTime) {
                        timeNotifier.value = newTime;
                      });
                    },
                  ),

                  const SizedBox(height: 40),

                  ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) return;

                      final elderId = InMemoryFaceStorage().getElderId();
                      if (elderId == null) return;

                      final timeStr =
                          '${timeNotifier.value.hour.toString().padLeft(2, '0')}:${timeNotifier.value.minute.toString().padLeft(2, '0')}';

                      final result = await _apiService.addTask(
                        elderId: elderId,
                        title: titleController.text.trim(),
                        description: descController.text.trim(),
                        time: timeStr,
                        date: _selectedDate,
                      );

                      if (result['success'] == true) {
                        _scheduleNotification(result['task']);
                        if (mounted) Navigator.pop(context);
                        _loadTasks();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      minimumSize: const Size(double.infinity, 60),
                    ),
                    child: const Text(
                      'ENREGISTRER',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTimePicker(TimeOfDay time, Function(TimeOfDay) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeColumn(
          'Heures',
          time.hour,
          24,
          (newHour) => onChanged(TimeOfDay(hour: newHour, minute: time.minute)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            ':',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        _buildTimeColumn(
          'Minutes',
          time.minute,
          60,
          (newMinute) =>
              onChanged(TimeOfDay(hour: time.hour, minute: newMinute)),
        ),
      ],
    );
  }

  Widget _buildTimeColumn(
    String label,
    int value,
    int max,
    Function(int) onChange,
  ) {
    return Column(
      children: [
        IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_up,
            size: 48,
            color: Colors.blue,
          ),
          onPressed: () => onChange((value + 1) % max),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 48,
            color: Colors.blue,
          ),
          onPressed: () => onChange((value - 1 + max) % max),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Future<void> _deleteTask(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Supprimer ?'),
        content: Text('Voulez-vous supprimer "$title" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'SUPPRIMER',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteTask(id);
        const channel = MethodChannel('fall_channel');
        await channel.invokeMethod('cancelTask', {'id': id});
        _loadTasks();
      } catch (e) {
        debugPrint('Error deleting task: $e');
      }
    }
  }

  // ====================== BUILD TASK ITEM - AVEC COULEURS + VERT QUAND TERMINÉ ======================
  Widget _buildTaskItem(dynamic task) {
    final bool isCompleted = task['isCompleted'] ?? false;
    final IconData taskIcon = _getTaskIcon(task['title']);

    // Couleur de base selon le type de tâche (utilisée seulement si non terminée)
    final Color baseColor = _getTaskColor(task['title']);

    // Si la tâche est terminée → tout devient vert
    final Color cardColor = isCompleted
        ? Colors.green[50]!
        : baseColor.withOpacity(0.08);
    final Color iconColor = isCompleted ? Colors.green[700]! : baseColor;
    final Color textColor = isCompleted ? Colors.green[900]! : Colors.black87;

    return Dismissible(
      key: Key(task['_id'].toString()),
      direction: isCompleted
          ? DismissDirection.none
          : DismissDirection.endToStart,
      onDismissed: (_) => _toggleTaskStatus(task),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 32),
        color: Colors.green[400],
        child: const Icon(Icons.check_circle, color: Colors.white, size: 40),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: isCompleted ? 4 : 8,
        color: cardColor,
        shadowColor: isCompleted
            ? Colors.green.withOpacity(0.2)
            : baseColor.withOpacity(0.25),
        child: InkWell(
          onTap: isCompleted ? null : () => _toggleTaskStatus(task),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green[100]
                        : baseColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(taskIcon, size: 42, color: iconColor),
                ),
                const SizedBox(width: 22),

                // Détails de la tâche
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 26, color: iconColor),
                          const SizedBox(width: 10),
                          Text(
                            task['time'],
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? Colors.green[700]
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      if (task['description']?.toString().trim().isNotEmpty ??
                          false) ...[
                        const SizedBox(height: 12),
                        Text(
                          task['description'],
                          style: TextStyle(
                            fontSize: 18,
                            color: isCompleted
                                ? Colors.green[800]
                                : Colors.grey[700],
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Statut + Bouton supprimer
                Column(
                  children: [
                    if (isCompleted)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 46,
                      )
                    else
                      Icon(
                        Icons.radio_button_unchecked,
                        color: baseColor.withOpacity(0.6),
                        size: 46,
                      ),
                    const SizedBox(height: 20),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                        size: 36,
                      ),
                      onPressed: () => _deleteTask(task['_id'], task['title']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ====================== COULEUR SELON TYPE DE TÂCHE ======================
  Color _getTaskColor(String title) {
    final String t = title.toLowerCase().trim();

    if (t.contains('medic') ||
        t.contains('pilule') ||
        t.contains('cachet') ||
        t.contains('médicament')) {
      return Colors.purple[600]!;
    }
    if (t.contains('march') || t.contains('promen') || t.contains('balade')) {
      return Colors.orange[600]!;
    }
    if (t.contains('repas') ||
        t.contains('manger') ||
        t.contains('déjeuner') ||
        t.contains('dîner')) {
      return Colors.red[600]!;
    }
    if (t.contains('eau') || t.contains('boire') || t.contains('hydrat')) {
      return Colors.blue[600]!;
    }
    if (t.contains('douche') || t.contains('toilette') || t.contains('bain')) {
      return Colors.teal[600]!;
    }
    if (t.contains('lecture') ||
        t.contains('lire') ||
        t.contains('journal') ||
        t.contains('livre')) {
      return Colors.brown[600]!;
    }
    if (t.contains('télé') || t.contains('tv') || t.contains('film')) {
      return Colors.indigo[600]!;
    }
    if (t.contains('appel') ||
        t.contains('téléphon') ||
        t.contains('famille')) {
      return Colors.green[600]!;
    }
    if (t.contains('sport') || t.contains('exercice') || t.contains('gymn')) {
      return Colors.pink[600]!;
    }
    if (t.contains('dormir') || t.contains('sieste')) {
      return Colors.deepPurple[600]!;
    }
    if (t.contains('musique') || t.contains('radio')) {
      return Colors.amber[600]!;
    }
    if (t.contains('jardin') || t.contains('plante')) {
      return Colors.green[700]!;
    }

    return Colors.blue[600]!; // défaut
  }

  IconData _getTaskIcon(String title) {
    final String t = title.toLowerCase().trim();

    // ====================== MÉDICAMENTS & SANTÉ ======================
    if (t.contains('medic') ||
        t.contains('pilule') ||
        t.contains('cachet') ||
        t.contains('médicament') ||
        t.contains('comprimé') ||
        t.contains('goutte') ||
        t.contains('sirop') ||
        t.contains('injection') ||
        t.contains('pansement')) {
      return Icons.medical_services;
    }

    // ====================== ACTIVITÉ PHYSIQUE & PROMENADE ======================
    if (t.contains('march') ||
        t.contains('promen') ||
        t.contains('balade') ||
        t.contains('marcher') ||
        t.contains('pied') ||
        t.contains('course') ||
        t.contains('jogging')) {
      return Icons.directions_walk;
    }

    // ====================== REPAS & ALIMENTATION ======================
    if (t.contains('repas') ||
        t.contains('manger') ||
        t.contains('déjeuner') ||
        t.contains('dîner') ||
        t.contains('diner') ||
        t.contains('petit déjeuner') ||
        t.contains('petit-dejeuner') ||
        t.contains('collation') ||
        t.contains('goûter') ||
        t.contains('fruit') ||
        t.contains('souper')) {
      return Icons.restaurant;
    }

    // ====================== HYDRATATION ======================
    if (t.contains('eau') ||
        t.contains('boire') ||
        t.contains('hydrat') ||
        t.contains('verre d\'eau') ||
        t.contains('tisane') ||
        t.contains('thé') ||
        t.contains('café')) {
      return Icons.water_drop;
    }

    // ====================== HYGIÈNE & DOUCHE ======================
    if (t.contains('douche') ||
        t.contains('bain') ||
        t.contains('toilette') ||
        t.contains('lavage') ||
        t.contains('se laver') ||
        t.contains('brosse à dent') ||
        t.contains('dent') ||
        t.contains('rasage') ||
        t.contains('coiffure') ||
        t.contains('cheveux')) {
      return Icons.shower;
    }

    // ====================== LECTURE & ACTIVITÉS INTELLECTUELLES ======================
    if (t.contains('lecture') ||
        t.contains('lire') ||
        t.contains('journal') ||
        t.contains('livre') ||
        t.contains('magazine') ||
        t.contains('nouvelle') ||
        t.contains('prière') ||
        t.contains('quran') ||
        t.contains('coran')) {
      return Icons.menu_book;
    }

    // ====================== TÉLÉVISION & LOISIRS ======================
    if (t.contains('télé') ||
        t.contains('tv') ||
        t.contains('film') ||
        t.contains('série') ||
        t.contains('émission') ||
        t.contains('journal télévisé') ||
        t.contains('match')) {
      return Icons.tv;
    }

    // ====================== APPEL & CONTACT FAMILLE ======================
    if (t.contains('appel') ||
        t.contains('téléphon') ||
        t.contains('appeler') ||
        t.contains('famille') ||
        t.contains('fils') ||
        t.contains('fille') ||
        t.contains('petit fils') ||
        t.contains('petite fille') ||
        t.contains('enfant') ||
        t.contains('voix')) {
      return Icons.phone;
    }

    // ====================== SPORT & EXERCICE ======================
    if (t.contains('sport') ||
        t.contains('exercice') ||
        t.contains('gymnastique') ||
        t.contains('gym') ||
        t.contains('mouvement') ||
        t.contains('étirement') ||
        t.contains('yoga')) {
      return Icons.fitness_center;
    }

    // ====================== COURSES & ACHATS ======================
    if (t.contains('course') ||
        t.contains('magasin') ||
        t.contains('acheter') ||
        t.contains('courses') ||
        t.contains('marché') ||
        t.contains('supermarché')) {
      return Icons.shopping_cart;
    }

    // ====================== SOMMEIL & REPOS ======================
    if (t.contains('dormir') ||
        t.contains('sieste') ||
        t.contains('coucher') ||
        t.contains('lit') ||
        t.contains('sommeil')) {
      return Icons.bed;
    }

    // ====================== MUSIQUE & RADIO ======================
    if (t.contains('musique') ||
        t.contains('radio') ||
        t.contains('chanter') ||
        t.contains('chanson')) {
      return Icons.music_note;
    }

    // ====================== JARDINAGE ======================
    if (t.contains('jardin') ||
        t.contains('plante') ||
        t.contains('arroser') ||
        t.contains('fleur')) {
      return Icons.local_florist;
    }

    // ====================== PRIÈRE / RELIGION ======================
    if (t.contains('prière') ||
        t.contains('prier') ||
        t.contains('mosquée') ||
        t.contains('église') ||
        t.contains('messe')) {
      return Icons.church;
    }

    // ====================== MÉDECIN & RENDEZ-VOUS ======================
    if (t.contains('médecin') ||
        t.contains('docteur') ||
        t.contains('rendez-vous') ||
        t.contains('rdv') ||
        t.contains('consultation') ||
        t.contains('hôpital')) {
      return Icons.medical_services_outlined;
    }

    // Icône par défaut
    return Icons.task_alt;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Mes Tâches Quotidiennes',
        showBackButton: true,
      ),
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: Column(
          children: [
            _buildCalendarStrip(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 6),
                    )
                  : _tasks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 140,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Aucune tâche aujourd\'hui',
                            style: TextStyle(fontSize: 24, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Appuyez sur + pour ajouter',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) =>
                          _buildTaskItem(_tasks[index]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: _addTask,
        backgroundColor: Colors.blue[700],
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: const Icon(Icons.add_rounded, size: 48, color: Colors.white),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCalendarStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              size: 36,
              color: Colors.blue,
            ),
            onPressed: () {
              setState(
                () => _selectedDate = _selectedDate.subtract(
                  const Duration(days: 1),
                ),
              );
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                DateFormat('d MMMM yyyy', 'fr_FR').format(_selectedDate),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 36,
              color: Colors.blue,
            ),
            onPressed: () {
              setState(
                () =>
                    _selectedDate = _selectedDate.add(const Duration(days: 1)),
              );
              _loadTasks();
            },
          ),
        ],
      ),
    );
  }
}
