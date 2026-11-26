class AuditLogRecord {
  final String eventId;
  final String action;
  final String? lockerId;
  final String? rentalId;
  final String? actorUsername;
  final String? actorName;
  final String? actorRole;
  final String? reason;
  final bool? endSession;
  final String? result;
  final DateTime? occurredAt;

  const AuditLogRecord({
    required this.eventId,
    required this.action,
    required this.lockerId,
    required this.rentalId,
    required this.actorUsername,
    required this.actorName,
    required this.actorRole,
    required this.reason,
    required this.endSession,
    required this.result,
    required this.occurredAt,
  });

  factory AuditLogRecord.fromJson(Map<String, dynamic> json) => AuditLogRecord(
    eventId: json['event_id'] as String,
    action: json['action'] as String,
    lockerId: json['locker_id'] as String?,
    rentalId: json['rental_id'] as String?,
    actorUsername: json['actor_username'] as String?,
    actorName: json['actor_name'] as String?,
    actorRole: json['actor_role'] as String?,
    reason: json['reason'] as String?,
    endSession: json['end_session'] as bool?,
    result: json['result'] as String?,
    occurredAt: json['occurred_at'] == null
        ? null
        : DateTime.parse(json['occurred_at'] as String),
  );

  String get title => switch (action) {
    'emergency_open' => 'Buka darurat',
    'locker_resolved' => 'Locker ditangani',
    _ => action,
  };
}
