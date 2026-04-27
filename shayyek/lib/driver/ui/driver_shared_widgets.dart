import 'package:flutter/material.dart';

import '../../app_text.dart';
import '../services/driver_task_service.dart';
import 'driver_palette.dart';

class DriverTopHeader extends StatelessWidget {
  const DriverTopHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.primary, palette.secondary],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class DriverSectionTitle extends StatelessWidget {
  const DriverSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class DriverInfoCard extends StatelessWidget {
  const DriverInfoCard({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.info_outline_rounded,
    this.color,
    this.action,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color? color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final tone = color ?? palette.secondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withOpacity(0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 10),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DriverEmptyState extends StatelessWidget {
  const DriverEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: palette.iconMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class DriverMetricTile extends StatelessWidget {
  const DriverMetricTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DriverPill extends StatelessWidget {
  const DriverPill({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class DriverLotCard extends StatelessWidget {
  const DriverLotCard({
    super.key,
    required this.lot,
    required this.live,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final DriverLot lot;
  final DriverLiveLot live;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lot.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite ? Colors.red : palette.iconMuted,
                  ),
                ),
              ],
            ),
            Text(
              lot.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DriverPill(
                  text: AppText.of(
                    context,
                    ar: 'فارغ ${live.free}',
                    en: 'Free ${live.free}',
                  ),
                  color: palette.available,
                ),
                DriverPill(
                  text: AppText.of(
                    context,
                    ar: 'مشغول ${live.occupied}',
                    en: 'Occupied ${live.occupied}',
                  ),
                  color: palette.occupied,
                ),
                DriverPill(
                  text: AppText.of(
                    context,
                    ar: '${lot.rateHou.toStringAsFixed(1)} ${lot.currency}/س',
                    en: '${lot.rateHou.toStringAsFixed(1)} ${lot.currency}/h',
                  ),
                  color: palette.secondary,
                ),
                if (lot.distanceKm != null && lot.distanceKm!.isFinite)
                  DriverPill(
                    text: AppText.of(
                      context,
                      ar: '${lot.distanceKm!.toStringAsFixed(1)} كم',
                      en: '${lot.distanceKm!.toStringAsFixed(1)} km',
                    ),
                    color: palette.primary,
                  ),
                if (live.degradedMode)
                  DriverPill(
                    text: AppText.of(
                      context,
                      ar: 'وضع محدود',
                      en: 'Degraded mode',
                    ),
                    color: Colors.orange,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DriverAnnouncementCard extends StatelessWidget {
  const DriverAnnouncementCard({
    super.key,
    required this.announcement,
  });

  final DriverAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    return DriverInfoCard(
      title: announcement.title,
      body: announcement.body,
      icon: Icons.campaign_outlined,
      color: announcement.targetType == 'lot' ? Colors.orange : Colors.blue,
    );
  }
}

class DriverStallCard extends StatelessWidget {
  const DriverStallCard({
    super.key,
    required this.stall,
    required this.onTap,
  });

  final DriverStall stall;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final statusColor = stall.isFree
        ? palette.available
        : (stall.isOccupied ? palette.occupied : palette.secondary);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stall.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DriverPill(
                  text: _stallStateLabel(context, stall),
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DriverPill(
                  text: AppText.of(
                    context,
                    ar: '${stall.rateHou.toStringAsFixed(1)} ${stall.currency}/س',
                    en: '${stall.rateHou.toStringAsFixed(1)} ${stall.currency}/h',
                  ),
                  color: palette.secondary,
                ),
                DriverPill(
                  text: AppText.of(
                    context,
                    ar: 'حد أقصى ${stall.maxStay} دقيقة',
                    en: 'Max ${stall.maxStay} min',
                  ),
                  color: palette.primary,
                ),
                if (stall.accessible)
                  DriverPill(
                    text: AppText.of(
                      context,
                      ar: 'ذوي الإعاقة',
                      en: 'Accessible',
                    ),
                    color: palette.available,
                  ),
                if (stall.ev)
                  DriverPill(
                    text: AppText.of(context, ar: 'كهربائي', en: 'EV'),
                    color: palette.secondary,
                  ),
                if (stall.reserved)
                  DriverPill(
                    text: AppText.of(context, ar: 'محجوز', en: 'Reserved'),
                    color: Colors.orange,
                  ),
              ],
            ),
            if (stall.lastSeen != null) ...[
              const SizedBox(height: 10),
              Text(
                AppText.of(
                  context,
                  ar: 'آخر تحديث: ${stall.lastSeen}',
                  en: 'Last update: ${stall.lastSeen}',
                ),
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DriverLabelValue extends StatelessWidget {
  const DriverLabelValue({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class DriverNotificationCard extends StatelessWidget {
  const DriverNotificationCard({
    super.key,
    required this.item,
    required this.isRead,
    required this.onMarkRead,
  });

  final DriverNotificationItem item;
  final bool isRead;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final tone = item.type == 'time_expiry'
        ? Colors.orange
        : (item.type == 'nearby_spot_opened'
            ? palette.available
            : palette.secondary);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DriverPill(
                text: _notificationTypeLabel(context, item.type),
                color: tone,
              ),
              const Spacer(),
              if (!isRead)
                TextButton(
                  onPressed: onMarkRead,
                  child: Text(
                    AppText.of(
                      context,
                      ar: 'تمييز كمقروء',
                      en: 'Mark as read',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.body,
            style: TextStyle(
              color: palette.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_notificationStatusLabel(context, item.status)} • ${item.createdAt ?? '-'}',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

String _stallStateLabel(BuildContext context, DriverStall stall) {
  if (stall.isFree) {
    return AppText.of(context, ar: 'متاح', en: 'Free');
  }
  if (stall.isOccupied) {
    return AppText.of(context, ar: 'مشغول', en: 'Occupied');
  }
  return stall.state;
}

String _notificationTypeLabel(BuildContext context, String type) {
  switch (type) {
    case 'time_expiry':
      return AppText.of(context, ar: 'تذكير الوقت', en: 'Time reminder');
    case 'nearby_spot_opened':
      return AppText.of(context, ar: 'موقف قريب', en: 'Nearby spot');
    default:
      return type;
  }
}

String _notificationStatusLabel(BuildContext context, String status) {
  switch (status) {
    case 'sent':
      return AppText.of(context, ar: 'تم الإرسال', en: 'Sent');
    case 'cancelled':
      return AppText.of(context, ar: 'ملغي', en: 'Cancelled');
    default:
      return status;
  }
}
