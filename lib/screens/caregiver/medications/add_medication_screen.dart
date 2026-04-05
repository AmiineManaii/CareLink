import 'dart:io';

import 'package:care_link/features/face_auth/face_storage.dart';
import 'package:care_link/models/medication.dart';
import 'package:care_link/services/api_service.dart';
import 'package:care_link/widgets/custom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AddMedicationScreen extends StatefulWidget {
  final Medication? medication;
  final String elderId;

  const AddMedicationScreen({
    super.key,
    this.medication,
    required this.elderId,
  });

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
  List<int> _selectedDays = [];
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  File? _imageFile;
  bool _isLoading = false;
  bool _isActive = true;

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
      final med = widget.medication!;
      _frequency = _frequencies.contains(med.frequency)
          ? med.frequency
          : 'Quotidien';
      _selectedDays = List.from(med.days);
      _startDate = med.startDate;
      _endDate = med.endDate;
      _isActive = med.active;
      if (med.times.isNotEmpty) {
        _times = med.times.map((t) {
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
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir une source'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Caméra'),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          TextButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text('Galerie'),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020), // Allow past dates for history
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
      setState(() => _times[index] = picked);
    }
  }

  void _addTime() {
    setState(() => _times.add(const TimeOfDay(hour: 12, minute: 0)));
  }

  void _removeTime(int index) {
    if (_times.length > 1) {
      setState(() => _times.removeAt(index));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final timesStrings = _times
          .map(
            (t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
          )
          .toList();

      final caregiverId = InMemoryFaceStorage().getCaregiverId();

      final medicationData = {
        'name': _nameController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'frequency': _frequency,
        'days': _selectedDays,
        'times': timesStrings,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate?.toIso8601String(),
        'instructions': _instructionsController.text.trim(),
        'elderId': widget.elderId,
        'caregiverId': caregiverId, // Ajout de l'ID de l'aidant
        'active': _isActive,
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
                  ? 'Médicament ajouté'
                  : 'Médicament mis à jour',
            ),
            backgroundColor: Colors.green,
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.medication != null
            ? 'Modifier le médicament'
            : 'Ajouter un médicament',
        showBackButton: true,
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(
                      'Informations Générales',
                      FontAwesomeIcons.pills,
                    ),
                    const SizedBox(height: 16),
                    _buildPhotoUpload(),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration(
                        'Nom du médicament',
                        Icons.medication,
                      ),
                      validator: (v) =>
                          v?.isEmpty ?? true ? 'Le nom est requis' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dosageController,
                      decoration: _buildInputDecoration(
                        'Dosage (ex: 500mg)',
                        Icons.science_outlined,
                      ),
                      validator: (v) =>
                          v?.isEmpty ?? true ? 'Le dosage est requis' : null,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      'Fréquence et Horaires',
                      FontAwesomeIcons.calendarCheck,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _frequency,
                      decoration: _buildInputDecoration(
                        'Fréquence',
                        Icons.repeat,
                      ),
                      items: _frequencies
                          .map(
                            (f) => DropdownMenuItem(value: f, child: Text(f)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _frequency = v!),
                    ),
                    if (_frequency == 'Hebdomadaire') ...[
                      const SizedBox(height: 16),
                      _buildDaySelector(),
                    ],
                    const SizedBox(height: 20),
                    _buildTimeSelector(),
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      'Durée du Traitement',
                      FontAwesomeIcons.hourglassHalf,
                    ),
                    const SizedBox(height: 16),
                    _buildDatePickers(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Autres', FontAwesomeIcons.circleInfo),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _instructionsController,
                      decoration: _buildInputDecoration(
                        'Instructions spéciales',
                        Icons.info_outline,
                        as: 3,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildStatusSwitch(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }

  Widget _buildPhotoUpload() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.purple.withOpacity(0.3), width: 2),
            image: _imageFile != null
                ? DecorationImage(
                    image: FileImage(_imageFile!),
                    fit: BoxFit.cover,
                  )
                : (widget.medication?.photoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(
                            '${ApiService().baseUrl}${widget.medication!.photoUrl}',
                          ),
                          fit: BoxFit.cover,
                        )
                      : null),
          ),
          child: _imageFile == null && widget.medication?.photoUrl == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 40, color: Colors.grey[600]),
                      const SizedBox(height: 4),
                      Text('Photo', style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        alignment: WrapAlignment.center,
        children: List.generate(7, (index) {
          final dayIndex = index + 1;
          final dayName = ['L', 'M', 'M', 'J', 'V', 'S', 'D'][index];
          final isSelected = _selectedDays.contains(dayIndex);
          return FilterChip(
            label: Text(
              dayName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
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
            backgroundColor: Colors.grey[100],
            selectedColor: Colors.purple[100],
            checkmarkColor: Colors.purple[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._times.asMap().entries.map((entry) {
          final index = entry.key;
          final time = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _selectTime(context, index),
                    icon: const Icon(
                      Icons.access_time_filled,
                      color: Colors.white,
                    ),
                    label: Text(
                      time.format(context),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (_times.length > 1)
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red[700],
                    ),
                    onPressed: () => _removeTime(index),
                  ),
              ],
            ),
          );
        }).toList(),
        TextButton.icon(
          onPressed: _addTime,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une heure'),
        ),
      ],
    );
  }

  Widget _buildDatePickers() {
    return Row(
      children: [
        Expanded(
          child: _buildDatePicker(
            'Date de début',
            _startDate,
            (date) => setState(() => _startDate = date),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDatePicker(
            'Date de fin',
            _endDate,
            (date) => setState(() => _endDate = date),
            isOptional: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? date,
    Function(DateTime) onSelect, {
    bool isOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2101),
            );
            if (picked != null) onSelect(picked);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date == null
                    ? (isOptional ? 'Aucune' : 'Choisir')
                    : DateFormat('dd/MM/yyyy').format(date),
              ),
              const Icon(Icons.calendar_today, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Traitement actif',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          Switch(
            value: _isActive,
            onChanged: (value) => setState(() => _isActive = value),
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_circle, color: Colors.white),
          label: Text(
            widget.medication == null ? 'ENREGISTRER' : 'METTRE À JOUR',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple[600],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    int as = 1,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[700]),
      prefixIcon: Icon(icon, color: Colors.purple[300]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.purple[600]!, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.purple[700], size: 22),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}
