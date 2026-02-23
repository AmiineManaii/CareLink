import 'package:flutter_test/flutter_test.dart';
import 'package:care_link/models/medication.dart';

void main() {
  group('Medication Model', () {
    test('should create Medication from JSON', () {
      final json = {
        '_id': '123',
        'name': 'Doliprane',
        'dosage': '1000mg',
        'frequency': 'Quotidien',
        'days': [1, 3, 5],
        'times': ['08:00', '20:00'],
        'startDate': '2023-01-01T00:00:00.000',
        'endDate': '2023-01-10T00:00:00.000',
        'instructions': 'Après repas',
        'photoUrl': '/uploads/photo.jpg',
        'active': true,
        'caregiverId': 'caregiver_1',
        'elderId': 'elder_1'
      };

      final medication = Medication.fromJson(json);

      expect(medication.id, '123');
      expect(medication.name, 'Doliprane');
      expect(medication.days.length, 3);
      expect(medication.days[0], 1);
      expect(medication.times.length, 2);
      expect(medication.times[0], '08:00');
      expect(medication.startDate.year, 2023);
      expect(medication.endDate?.day, 10);
      expect(medication.photoUrl, '/uploads/photo.jpg');
    });

    test('should convert Medication to JSON', () {
      final medication = Medication(
        id: '123',
        name: 'Doliprane',
        dosage: '1000mg',
        frequency: 'Quotidien',
        days: [2, 4],
        times: ['08:00'],
        startDate: DateTime(2023, 1, 1),
        endDate: DateTime(2023, 1, 10),
        instructions: 'Test',
        caregiverId: 'c1',
        elderId: 'e1',
      );

      final json = medication.toJson();

      expect(json['id'], '123');
      expect(json['name'], 'Doliprane');
      expect(json['days'], [2, 4]);
      expect(json['startDate'], isNotNull);
      expect(json['caregiverId'], 'c1');
    });

    test('should handle missing optional fields in JSON', () {
      final json = {
        '_id': '123',
        'name': 'Advil',
        'dosage': '200mg',
        'frequency': 'Au besoin',
        'startDate': '2023-01-01T00:00:00.000',
      };

      final medication = Medication.fromJson(json);

      expect(medication.name, 'Advil');
      expect(medication.endDate, null);
      expect(medication.times, isEmpty);
      expect(medication.active, true); // Default value
    });
  });
}
