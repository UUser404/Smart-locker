import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/locker.dart';
import '../models/rental_record.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==================== LOCKERS ====================
  Stream<List<Locker>> streamLockers() {
    return _db
        .collection('lockers')
        .orderBy('lockerIndex')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Locker.fromFirestore(d)).toList());
  }

  Future<List<Locker>> fetchLockers() async {
    final snap = await _db.collection('lockers').orderBy('lockerIndex').get();
    return snap.docs.map((d) => Locker.fromFirestore(d)).toList();
  }

  // ==================== RENTALS ====================
  Stream<List<RentalRecord>> streamRentals({int limit = 200}) {
    return _db
        .collection('rentals')
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => RentalRecord.fromFirestore(d)).toList(),
        );
  }

  // ==================== STATISTIK ====================
  RentalStats computeStats(List<RentalRecord> rentals) {
    if (rentals.isEmpty) {
      return RentalStats(
        totalRentals: 0,
        avgDurationSeconds: 0,
        busiestLockerId: null,
      );
    }
    final completed = rentals
        .where((r) => r.totalDurationSeconds != null)
        .toList();
    final avg = completed.isEmpty
        ? 0
        : completed.fold<int>(0, (s, r) => s + r.totalDurationSeconds!) ~/
              completed.length;
    final freq = <String, int>{};
    for (final r in rentals) {
      freq[r.lockerId] = (freq[r.lockerId] ?? 0) + 1;
    }
    final busiest = freq.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    return RentalStats(
      totalRentals: rentals.length,
      avgDurationSeconds: avg,
      busiestLockerId: busiest,
    );
  }
}
