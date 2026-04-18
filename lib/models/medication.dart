class Medication {
  final String id;
  final String name;
  final String dosage;
  final String
  frequency; // e.g., "Quotidien", "Hebdomadaire", "Mensuel", "Au besoin"
  final List<int> days; // 1=Monday, 7=Sunday. Empty if not applicable.
  final List<String> times; // e.g., ["08:00", "20:00"]
  final DateTime startDate;
  final DateTime? endDate;
  final String? instructions;
  final String? photoUrl;
  final bool active;
  final String? caregiverId; // ID of the caregiver who added it
  final String? elderId; // ID of the elder who takes it

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    this.days = const [],
    required this.times,
    required this.startDate,
    this.endDate,
    this.instructions,
    this.photoUrl,
    this.active = true,
    this.caregiverId,
    this.elderId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'days': days,
      'times': times,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'instructions': instructions,
      'photoUrl': photoUrl,
      'active': active,
      'caregiverId': caregiverId,
      'elderId': elderId,
    };
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      dosage: json['dosage'] ?? '',
      frequency: json['frequency'] ?? '',
      days: json['days'] != null ? List<int>.from(json['days']) : [],
      times: List<String>.from(json['times'] ?? []),
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      instructions: json['instructions'],
      photoUrl: json['photoUrl'],
      active: json['active'] ?? true,
      caregiverId: json['caregiverId'],
      elderId: json['elderId'],
    );
  }
}
