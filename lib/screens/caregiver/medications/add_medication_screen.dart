import 'dart:io';

import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:care_link/models/medication.dart';
import 'package:care_link/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AddMedicationScreen extends StatefulWidget {
  final Medication? medication;
  const AddMedicationScreen({super.key, this.medication});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _instructionsController;

  String _frequency = 'Quotidien';
  final List<String> _frequencies = [
    'Quotidien',
    'Hebdomadaire',
    'Mensuel',
    'Au besoin',
  ];

  List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  List<int> _selectedDays = []; // 1=Monday, 7=Sunday
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.medication?.name ?? '',
    );
    _dosageController = TextEditingController(
      text: widget.medication?.dosage ?? '',
    );
    _instructionsController = TextEditingController(
      text: widget.medication?.instructions ?? '',
    );

    if (widget.medication != null) {
      _frequency = widget.medication!.frequency;
      if (!_frequencies.contains(_frequency)) {
        _frequency = 'Quotidien';
      }
      _selectedDays = List.from(widget.medication!.days);
      _startDate = widget.medication!.startDate;
      _endDate = widget.medication!.endDate;
      if (widget.medication!.times.isNotEmpty) {
        _times = widget.medication!.times.map((t) {
          final parts = t.split(':');
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }).toList();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    if (picked != null) {
      setState(() {
        _times[index] = picked;
      });
    }
  }

  void _addTime() {
    setState(() {
      _times.add(const TimeOfDay(hour: 12, minute: 0));
    });
  }

  void _removeTime(int index) {
    setState(() {
      _times.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez ajouter au moins une heure de prise'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final elderId = InMemoryFaceStorage().getElderId();
      final caregiverId = InMemoryFaceStorage().getCaregiverId();

      if (elderId == null || caregiverId == null) {
        throw Exception('Informations de session manquantes');
      }

      final timesStrings = _times
          .map(
            (t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
          )
          .toList();

      // Note: Image upload logic would go here.
      // For now we send null or implement separate upload endpoint.
      // Assuming API handles JSON body.

      final medicationData = {
        'name': _nameController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'frequency': _frequency,
        'days': _selectedDays,
        'times': timesStrings,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate?.toIso8601String(),
        'instructions': _instructionsController.text.trim(),
        'caregiverId': caregiverId,
        'elderId': elderId,
      };

      if (widget.medication == null) {
        await ApiService().addMedication(medicationData, image: _imageFile);
      } else {
        await ApiService().updateMedication(
          widget.medication!.id,
          medicationData,
          image: _imageFile,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.medication == null
                  ? 'Médicament ajouté avec succès'
                  : 'Médicament mis à jour avec succès',
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.medication != null
              ? 'Modifier le médicament'
              : 'Ajouter un médicament',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo Upload
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : (widget.medication?.photoUrl != null
                                        ? NetworkImage(
                                            '${ApiService().baseUrl}${widget.medication!.photoUrl}',
                                          )
                                        : null)
                                    as ImageProvider?,
                          child:
                              _imageFile == null &&
                                  widget.medication?.photoUrl == null
                              ? const Icon(
                                  Icons.camera_alt,
                                  size: 40,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du médicament',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.medication),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),

                    // Dosage
                    TextFormField(
                      controller: _dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage (ex: 500mg, 1 comprimé)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),

                    // Frequency
                    DropdownButtonFormField<String>(
                      value: _frequency,
                      decoration: const InputDecoration(
                        labelText: 'Fréquence',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      items: _frequencies
                          .map(
                            (f) => DropdownMenuItem(value: f, child: Text(f)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _frequency = v!),
                    ),

                    if (_frequency == 'Hebdomadaire' ||
                        _frequency == 'Au besoin') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Jours spécifiques (Optionnel)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Wrap(
                        spacing: 8.0,
                        children: List.generate(7, (index) {
                          final dayIndex = index + 1; // 1=Mon, 7=Sun
                          final dayName = [
                            'L',
                            'M',
                            'M',
                            'J',
                            'V',
                            'S',
                            'D',
                          ][index];
                          final isSelected = _selectedDays.contains(dayIndex);
                          return FilterChip(
                            label: Text(dayName),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedDays.add(dayIndex);
                                } else {
                                  _selectedDays.remove(dayIndex);
                                }
                                _selectedDays.sort();
                              });
                            },
                            selectedColor: Colors.blue[100],
                            checkmarkColor: Colors.blue[800],
                          );
                        }),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Times
                    const Text(
                      'Heures de prise',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._times.asMap().entries.map((entry) {
                      final index = entry.key;
                      final time = entry.value;
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectTime(context, index),
                              icon: const Icon(Icons.access_time),
                              label: Text(time.format(context)),
                            ),
                          ),
                          if (_times.length > 1)
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _removeTime(index),
                            ),
                        ],
                      );
                    }).toList(),
                    TextButton.icon(
                      onPressed: _addTime,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter une heure'),
                    ),
                    const SizedBox(height: 24),

                    // Dates
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date de début'),
                              OutlinedButton.icon(
                                onPressed: () => _selectDate(context, true),
                                icon: const Icon(Icons.calendar_today),
                                label: Text(
                                  DateFormat('dd/MM/yyyy').format(_startDate),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date de fin (Optionnel)'),
                              OutlinedButton.icon(
                                onPressed: () => _selectDate(context, false),
                                icon: const Icon(Icons.event_busy),
                                label: Text(
                                  _endDate == null
                                      ? 'Aucune'
                                      : DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(_endDate!),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Instructions
                    TextFormField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(
                        labelText: 'Instructions spéciales',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'ENREGISTRER',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
