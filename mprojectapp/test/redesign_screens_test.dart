import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mprojectapp/models/locker.dart';
import 'package:mprojectapp/models/rental_record.dart';
import 'package:mprojectapp/screens/admin_analytics_screen.dart';
import 'package:mprojectapp/screens/admin_history_screen.dart';
import 'package:mprojectapp/screens/petugas_locker_screens.dart';
import 'package:mprojectapp/widgets/design_system_widgets.dart';

void main() {
  testWidgets('locker card marks unavailable ESP32 status without guessing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              LockerSummaryCard(
                locker: Locker(
                  lockerId: 'locker_01',
                  status: LockerStatus.occupied,
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Status ESP32 belum tersedia dari API'), findsOneWidget);
    expect(find.text('Online'), findsNothing);
  });

  testWidgets('admin summary shows emergency data as unavailable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminAnalyticsScreen(
          stats: RentalStats(totalRentals: 1, avgDurationSeconds: 0),
          rentals: [
            RentalRecord(
              rentalId: 'R-001',
              lockerId: 'locker_01',
              nama: 'Budi Santoso',
              noHp: '0812****7890',
              startedAt: DateTime.now(),
            ),
          ],
          lockers: const [],
          loading: false,
          error: null,
          onRefresh: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sewa hari ini'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DesignMetricCard &&
            widget.label == 'Sewa hari ini' &&
            widget.value == '1',
      ),
      findsOneWidget,
    );
    expect(find.text('Buka darurat'), findsOneWidget);
    expect(find.text('Log audit belum tersedia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin desktop summary includes event and usage panels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminAnalyticsScreen(
          stats: RentalStats(totalRentals: 1, avgDurationSeconds: 684),
          rentals: [
            RentalRecord(
              rentalId: 'R-001',
              lockerId: 'locker_01',
              nama: 'Budi Santoso',
              noHp: '0812****7890',
              startedAt: DateTime.now(),
            ),
          ],
          lockers: [
            Locker(
              lockerId: 'locker_01',
              status: LockerStatus.occupied,
              elapsedSeconds: 684,
            ),
            Locker(
              lockerId: 'locker_02',
              status: LockerStatus.needsAttention,
              unlockedSince: DateTime.now().subtract(
                const Duration(minutes: 6, seconds: 12),
              ),
            ),
          ],
          loading: false,
          error: null,
          onRefresh: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kejadian terbaru'), findsOneWidget);
    expect(find.text('Pemakaian per jam'), findsOneWidget);
    expect(find.text('Grafik belum tersedia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('emergency open requires a continuous two-second hold', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? submittedReason;
    bool? submittedEndSession;
    await tester.pumpWidget(
      MaterialApp(
        home: LockerDetailScreen(
          locker: Locker(lockerId: 'locker_01', status: LockerStatus.occupied),
          onHandle: () async => false,
          onEmergencyOpen: (reason, endSession) async {
            submittedReason = reason;
            submittedEndSession = endSession;
          },
        ),
      ),
    );

    await tester.tap(find.text('Buka darurat locker_01'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pintu macet'));
    await tester.tap(find.text('Akhiri sesi'));
    await tester.pumpAndSettle();

    final holdLabel = find.text('Tahan 2 detik untuk membuka');
    await tester.ensureVisible(holdLabel);
    await tester.pumpAndSettle();
    final shortHold = await tester.startGesture(tester.getCenter(holdLabel));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Tahan...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(submittedReason, isNull);
    await shortHold.up();
    await tester.pump();
    expect(holdLabel, findsOneWidget);
    await tester.ensureVisible(holdLabel);
    await tester.pumpAndSettle();
    final fullHold = await tester.startGesture(tester.getCenter(holdLabel));
    await tester.pump(const Duration(milliseconds: 2100));
    await fullHold.up();
    await tester.pumpAndSettle();

    expect(submittedReason, 'Pintu macet');
    expect(submittedEndSession, isTrue);
    expect(tester.takeException(), isNull);
  });

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
