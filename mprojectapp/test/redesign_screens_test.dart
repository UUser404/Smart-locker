import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mprojectapp/models/locker.dart';
import 'package:mprojectapp/models/rental_record.dart';
import 'package:mprojectapp/screens/admin_history_screen.dart';
import 'package:mprojectapp/screens/petugas_locker_screens.dart';

void main() {
  testWidgets('resolve stays disabled until both physical checks are marked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var resolveCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LockerHandlingScreen(
          locker: Locker(
            lockerId: 'locker_02',
            status: LockerStatus.needsAttention,
          ),
          onResolve: () async {
            resolveCalls++;
          },
        ),
      ),
    );

    FilledButton resolveButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Selesaikan & kosongkan locker'),
    );

    expect(resolveButton().onPressed, isNull);
    final checks = find.byType(CheckboxListTile);
    await tester.ensureVisible(checks.first);
    await tester.tap(checks.first);
    await tester.pump();
    expect(resolveButton().onPressed, isNull);
    await tester.ensureVisible(checks.last);
    await tester.tap(checks.last);
    await tester.pump();

    expect(resolveButton().onPressed, isNotNull);
    expect(resolveCalls, 0);
  });

  testWidgets('rental history search filters visible sessions', (tester) async {
    final now = DateTime.now();
    final rentals = [
      RentalRecord(
        rentalId: 'R-001',
        lockerId: 'locker_01',
        nama: 'Budi Santoso',
        noHp: '0812****7890',
        startedAt: now,
      ),
      RentalRecord(
        rentalId: 'R-002',
        lockerId: 'locker_02',
        nama: 'Sinta Rahma',
        noHp: '0857****2201',
        startedAt: now.subtract(const Duration(minutes: 50)),
        endedAt: now.subtract(const Duration(minutes: 5)),
        totalDurationSeconds: 2700,
        status: 'completed',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: AdminHistoryScreen(rentals: rentals, onRefresh: () async {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Budi Santoso'), findsOneWidget);
    expect(find.textContaining('Sinta Rahma'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'R-002');
    await tester.pumpAndSettle();

    expect(find.textContaining('Budi Santoso'), findsNothing);
    expect(find.textContaining('Sinta Rahma'), findsOneWidget);
  });
}
