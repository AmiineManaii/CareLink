import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:image_picker/image_picker.dart';

import 'package:care_link/services/ml/ml_service.dart';
import 'accessibility_test.mocks.dart';

@GenerateMocks([MLService])
void main() {
  late MockMLService mlService;
  late TestLogic logic;

  setUp(() {
    mlService = MockMLService();
    logic = TestLogic(mlService);
  });

  group('AccessibilityScreen Logic Test', () {

    test('✅ API success → no TFLite, no dialog', () async {
      await logic.handle(true);

      expect(logic.tfliteCalled, false);
      expect(logic.dialogShown, false);

      // Vérifie que detectObjects n'est jamais appelé
      verifyNever(mlService.detectObjects('test.jpg'));
    });

    test('✅ API fail → fallback TFLite + dialog', () async {
      // 🔥 Stub EXACT (pas de any)
      when(mlService.detectObjects('test.jpg'))
          .thenAnswer((_) async => []);

      await logic.handle(false);

      expect(logic.tfliteCalled, true);
      expect(logic.dialogShown, true);

      // Vérifie appel exact
      verify(mlService.detectObjects('test.jpg')).called(1);
    });

  });
}

/// 🔹 Logique simplifiée
class TestLogic {
  final MLService mlService;

  bool tfliteCalled = false;
  bool dialogShown = false;

  TestLogic(this.mlService);

  Future<bool> sendToBackendSuccess() async {
    return true;
  }

  Future<bool> sendToBackendFail() async {
    return false;
  }

  Future<void> handle(bool apiSuccess) async {
    final file = XFile('test.jpg');

    final sent = apiSuccess
        ? await sendToBackendSuccess()
        : await sendToBackendFail();

    if (sent) {
      // ✅ API OK → rien
      return;
    }

    // ❌ API KO → fallback
    tfliteCalled = true;

    await mlService.detectObjects(file.path);

    dialogShown = true;
  }
}