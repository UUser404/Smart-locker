import 'package:flutter/material.dart';

import '../models/locker.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

StatusStyle lockerStatusStyle(LockerStatus status) => switch (status) {
  LockerStatus.empty => AppStatus.success,
  LockerStatus.occupied => AppStatus.info,
  LockerStatus.needsAttention => AppStatus.warning,
};

String lockerStatusLabel(LockerStatus status) => switch (status) {
  LockerStatus.empty => 'Kosong',
  LockerStatus.occupied => 'Disewa',
  LockerStatus.needsAttention => 'Perhatian',
};

class DesignStatusBadge extends StatelessWidget {
  const DesignStatusBadge({
    required this.label,
    required this.style,
    super.key,
  });

  final String label;
  final StatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2, vertical: 5),
      decoration: BoxDecoration(
        color: style.container,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppType.micro.copyWith(color: style.text, letterSpacing: 0.2),
      ),
    );
  }
}

class DesignMetricCard extends StatelessWidget {
  const DesignMetricCard({
    required this.label,
    required this.value,
    required this.style,
    this.highlighted = false,
    this.supportingText,
    this.valueColor,
    this.valueOnTop = false,
    super.key,
  });

  final String label;
  final String value;
  final StatusStyle style;
  final bool highlighted;
  final String? supportingText;
  final Color? valueColor;
  final bool valueOnTop;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: AppType.caption.copyWith(
        color: highlighted ? style.text : AppColors.neutralTextMuted,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final valueWidget = Text(
      value,
      style: AppType.headline.copyWith(color: valueColor ?? style.main),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: BoxDecoration(
        color: highlighted ? style.tint : AppColors.neutralSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: highlighted ? style.border : AppColors.neutralBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (valueOnTop) valueWidget else labelWidget,
          const SizedBox(height: AppSpace.s1),
          if (valueOnTop) labelWidget else valueWidget,
          if (supportingText != null) ...[
            const SizedBox(height: AppSpace.s1),
            Text(
              supportingText!,
              style: AppType.micro.copyWith(
                color: highlighted ? style.text : AppColors.neutralTextMuted,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class DesignSectionHeader extends StatelessWidget {
  const DesignSectionHeader({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppType.subtitle.copyWith(color: AppColors.neutralInk),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class LockerSummaryCard extends StatelessWidget {
  const LockerSummaryCard({
    required this.locker,
    required this.onTap,
    this.tenantName,
    super.key,
  });

  final Locker locker;
  final VoidCallback onTap;
  final String? tenantName;

  @override
  Widget build(BuildContext context) {
    final style = lockerStatusStyle(locker.status);
    final detail = switch (locker.status) {
      LockerStatus.empty => 'Siap disewa',
      LockerStatus.occupied => tenantName ?? 'Sedang digunakan',
      LockerStatus.needsAttention =>
        'Perlu diperiksa · ${locker.needsAttentionSinceLabel}',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.s2),
      decoration: BoxDecoration(
        color: locker.status == LockerStatus.needsAttention
            ? style.tint
            : AppColors.neutralSurface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: locker.status == LockerStatus.needsAttention
              ? style.border
              : AppColors.neutralBorder,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: style.container,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      locker.lockerId.replaceAll(RegExp(r'[^0-9]'), ''),
                      style: AppType.bodyStrong.copyWith(color: style.main),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(locker.lockerId, style: AppType.bodyStrong),
                        const SizedBox(height: AppSpace.s1),
                        Text(
                          detail,
                          style: AppType.caption.copyWith(
                            color: AppColors.neutralTextMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  DesignStatusBadge(
                    label: lockerStatusLabel(locker.status),
                    style: style,
                  ),
                  const SizedBox(width: AppSpace.s1),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.neutralTextDisabled,
                  ),
                ],
              ),
              if (locker.status == LockerStatus.occupied) ...[
                const SizedBox(height: AppSpace.s3),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: style.main),
                    const SizedBox(width: AppSpace.s2),
                    Text(
                      locker.displayDuration,
                      style: AppType.bodyStrong.copyWith(color: style.main),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Text(
                      'durasi sewa',
                      style: AppType.caption.copyWith(
                        color: AppColors.neutralTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.s2),
              const Divider(height: 1),
              const SizedBox(height: AppSpace.s2),
              Row(
                children: [
                  const Icon(
                    Icons.sensors_outlined,
                    size: 14,
                    color: AppColors.neutralTextMuted,
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Text(
                      'Status ESP32 belum tersedia dari API',
                      style: AppType.caption.copyWith(
                        color: AppColors.neutralTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DesignEmptyState extends StatelessWidget {
  const DesignEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.neutralTextMuted),
            const SizedBox(height: AppSpace.s3),
            Text(title, style: AppType.subtitle, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.s2),
            Text(
              message,
              style: AppType.bodySm.copyWith(color: AppColors.neutralTextMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
