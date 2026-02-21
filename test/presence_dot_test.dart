import 'package:care_link/screens/caregiver/caregiver_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PresenceDot est vert quand en ligne', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ElderStatusIndicator(
            online: true,
            title: 'En ligne',
            subtitle: null,
            onTap: null,
          ),
        ),
      ),
    );

    final dotFinder = find.byType(Container).last;
    final container = tester.widget<Container>(dotFinder);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.green);
  });

  testWidgets('PresenceDot est rouge quand hors ligne', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ElderStatusIndicator(
            online: false,
            title: 'Hors ligne',
            subtitle: null,
            onTap: null,
          ),
        ),
      ),
    );

    final dotFinder = find.byType(Container).last;
    final container = tester.widget<Container>(dotFinder);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.color, Colors.red);
  });
}
