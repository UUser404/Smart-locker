import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mprojectapp/widgets/dashboard_widgets.dart';

void main() {
  testWidgets(
    'StatGrid lays out four cards in one row on wide screens',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatGrid(
                cards: [
                  _card('Kosong'),
                  _card('Terisi'),
                  _card('Perhatian'),
                  _card('Total'),
                ],
              ),
            ),
          ),
        ),
      );

      final cardTops = [
        for (final label in ['Kosong', 'Terisi', 'Perhatian', 'Total'])
          tester.getTopLeft(find.text(label)).dy,
      ];

      expect(cardTops.toSet(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}

StatCard _card(String label) => StatCard(
  label: label,
  value: '1',
  icon: Icons.lock,
  color: Colors.indigo,
);
