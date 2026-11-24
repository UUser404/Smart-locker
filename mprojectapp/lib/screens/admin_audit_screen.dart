import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../widgets/design_system_widgets.dart';

class AdminAuditScreen extends StatelessWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Log Audit'),
            Text(
              'Tindakan sistem dan pengguna',
              style: TextStyle(fontSize: 12, color: AppColors.neutralTextMuted),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSize.contentMax),
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s4),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _AuditFilterChip(label: 'Semua', selected: true),
                    _AuditFilterChip(label: 'Darurat'),
                    _AuditFilterChip(label: 'Resolve'),
                    _AuditFilterChip(label: 'Pengaturan'),
                    _AuditFilterChip(label: 'Perangkat'),
                    _AuditFilterChip(label: 'Akses data'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s4),
              const SizedBox(
                height: 360,
                child: DesignEmptyState(
                  icon: Icons.shield_outlined,
                  title: 'Log audit belum tersedia',
                  message:
                      'Server belum menyediakan endpoint audit. Data contoh tidak ditampilkan agar riwayat tindakan tetap akurat.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditFilterChip extends StatelessWidget {
  const _AuditFilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.s2),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: null,
        selectedColor: AppColors.neutralInk,
        labelStyle: TextStyle(
          color: selected
              ? AppColors.neutralOnInverse
              : AppColors.neutralTextBody,
        ),
      ),
    );
  }
}
