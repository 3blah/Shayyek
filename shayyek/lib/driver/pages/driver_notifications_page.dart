import 'package:flutter/material.dart';

import '../../app_text.dart';
import '../services/driver_task_service.dart';
import '../ui/driver_shared_widgets.dart';

class DriverNotificationsPage extends StatelessWidget {
  const DriverNotificationsPage({
    super.key,
    required this.notifications,
    required this.readIds,
    required this.onRefresh,
    required this.onMarkRead,
  });

  final List<DriverNotificationItem> notifications;
  final Set<String> readIds;
  final Future<void> Function() onRefresh;
  final void Function(String notificationId) onMarkRead;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          DriverTopHeader(
            title: AppText.of(context,
                ar: 'إشعارات السائق', en: 'Driver notifications'),
            subtitle: AppText.of(
              context,
              ar: 'تعرض إشعارات المستخدم الحالي فقط من الأحدث إلى الأقدم.',
              en: 'Shows current user notifications from newest to oldest.',
            ),
            icon: Icons.notifications_active_outlined,
          ),
          const SizedBox(height: 18),
          if (notifications.isEmpty)
            DriverEmptyState(
              title: AppText.of(context,
                  ar: 'لا توجد إشعارات', en: 'No notifications'),
              body: AppText.of(
                context,
                ar: 'ستظهر هنا تنبيهات الوقت والمواقف القريبة وغيرها عند إنشائها.',
                en: 'Time reminders and nearby spot alerts will appear here when created.',
              ),
              icon: Icons.notifications_off_outlined,
            )
          else
            ...notifications.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DriverNotificationCard(
                  item: item,
                  isRead: readIds.contains(item.id),
                  onMarkRead: () => onMarkRead(item.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
