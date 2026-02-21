import 'package:care_link/screens/caregiver/caregiver_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ElderStatusIndicator affiche une carte verte quand en ligne',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ElderStatusIndicator(
            online: true,
            title: 'En ligne',
            subtitle: 'Test',
            onTap: null,
          ),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byKey(const Key('elderStatusCircleContainer')),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.green);
  });

  testWidgets('ElderStatusIndicator affiche une carte rouge quand hors ligne',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ElderStatusIndicator(
            online: false,
            title: 'Hors ligne',
            subtitle: 'Test',
            onTap: null,
          ),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.byKey(const Key('elderStatusCircleContainer')),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.red);
  });

  testWidgets(
      'ElderStatusIndicator ouvre un dialogue quand on tape sur la carte',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElderStatusIndicator(
              online: true,
              title: 'En ligne',
              subtitle: 'Test',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const AlertDialog(
                    title: Text('Profil'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('elderStatusCircleTap')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });
}

