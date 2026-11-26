import 'package:flutter/material.dart';

import '../models/audit_log_record.dart';
import '../theme/app_tokens.dart';
import '../widgets/audit_log_feed.dart';

class AdminAuditScreen extends StatelessWidget {
  const AdminAuditScreen({
    required this.logs,
    required this.loading,
    required this.onRefresh,
    this.error,
    super.key,
  });

  final List<AuditLogRecord> logs;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Log Audit'),
            Text(
              'Tindakan sistem dan pengguna',
              style: AppType.caption.copyWith(
                color: AppColors.neutralTextMuted,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSize.contentMax),
          child: AuditLogFeed(
            logs: logs,
            loading: loading,
            error: error,
            onRefresh: onRefresh,
          ),
        ),
      ),
    );
  }
}
