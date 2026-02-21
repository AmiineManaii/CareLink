import 'package:care_link/screens/caregiver/caregiver_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CaregiverNoElderCard affiche le message et le bouton support', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaregiverNoElderCard(
            onSupportTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Aucun senior lié'), findsOneWidget);
    expect(find.text('Contacter le support'), findsOneWidget);

    await tester.tap(find.text('Contacter le support'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('CaregiverQuickActionsSection affiche les 4 actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CaregiverQuickActionsSection())),
    );

    expect(find.text('Localisation'), findsOneWidget);
    expect(find.text('Santé'), findsOneWidget);
    expect(find.text('Alertes'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
  });

  testWidgets(
    'CaregiverHomeConnectedContent affiche actions rapides et fonctionnalités',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CaregiverHomeConnectedContent()),
          ),
        ),
      );

      expect(find.text('Actions rapides'), findsOneWidget);
      expect(find.text('Plus de fonctionnalités'), findsOneWidget);
    },
  );
}
