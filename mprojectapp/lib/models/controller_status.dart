class ControllerStatus {
  final String controllerId;
  final bool online;
  final DateTime? lastSeenAt;
  final int onlineWindowSeconds;

  const ControllerStatus({
    required this.controllerId,
    required this.online,
    required this.lastSeenAt,
    required this.onlineWindowSeconds,
  });

  factory ControllerStatus.fromJson(Map<String, dynamic> json) =>
      ControllerStatus(
        controllerId: json['controller_id'] as String,
        online: json['online'] as bool,
        lastSeenAt: json['last_seen_at'] == null
            ? null
            : DateTime.parse(json['last_seen_at'] as String),
        onlineWindowSeconds: json['online_window_seconds'] as int,
      );
}
