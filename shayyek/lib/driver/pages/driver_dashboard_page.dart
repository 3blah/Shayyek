import 'package:flutter/material.dart';

import '../../app_text.dart';
import '../services/driver_task_service.dart';
import '../ui/driver_palette.dart';
import '../ui/driver_shared_widgets.dart';

class DriverDashboardPage extends StatelessWidget {
  const DriverDashboardPage({
    super.key,
    required this.user,
    required this.nearbyLots,
    required this.liveLots,
    required this.favoriteLotIds,
    required this.announcements,
    required this.activeSession,
    required this.activeLotName,
    required this.activeStallLabel,
    required this.totalFree,
    required this.totalOccupied,
    required this.nearestLotLabel,
    required this.favoriteCount,
    required this.onRefresh,
    required this.onOpenLots,
    required this.onOpenNotifications,
    required this.onOpenSessions,
    required this.onOpenFavorites,
    required this.onOpenProfile,
    required this.onOpenLot,
    required this.onToggleFavorite,
    required this.onViewActiveSession,
    required this.onEndSession,
    this.errorText,
  });

  final DriverUserContext? user;
  final List<DriverLot> nearbyLots;
  final Map<String, DriverLiveLot> liveLots;
  final Set<String> favoriteLotIds;
  final List<DriverAnnouncement> announcements;
  final DriverSession? activeSession;
  final String? activeLotName;
  final String? activeStallLabel;
  final int totalFree;
  final int totalOccupied;
  final String nearestLotLabel;
  final int favoriteCount;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenLots;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSessions;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenProfile;
  final void Function(String lotId) onOpenLot;
  final void Function(String lotId) onToggleFavorite;
  final VoidCallback onViewActiveSession;
  final VoidCallback onEndSession;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );
    final welcomeName = user?.name.trim().isNotEmpty == true
        ? user!.name
        : AppText.of(context, ar: 'الضيف', en: 'Guest');

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
        children: [
          DriverTopHeader(
            title: AppText.of(
              context,
              ar: 'مرحباً $welcomeName',
              en: 'Welcome $welcomeName',
            ),
            subtitle: user == null
                ? AppText.of(
                    context,
                    ar: 'استعرض المواقف المتاحة كضيف.',
                    en: 'Browse available lots as a guest.',
                  )
                : AppText.of(
                    context,
                    ar: 'الحالة الحية والمواقف الأقرب أمامك.',
                    en: 'Live status and nearby parking are ready.',
                  ),
            icon: Icons.dashboard_customize_rounded,
            trailing: IconButton(
              onPressed: onOpenNotifications,
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
              ),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 14),
            DriverInfoCard(
              title: AppText.of(
                context,
                ar: 'تنبيه اتصال',
                en: 'Connection alert',
              ),
              body: errorText!,
              icon: Icons.wifi_off_rounded,
              color: palette.occupied,
            ),
          ],
          if (activeSession != null) ...[
            const SizedBox(height: 14),
            DriverInfoCard(
              title: AppText.of(
                context,
                ar: 'جلسة نشطة',
                en: 'Active session',
              ),
              body:
                  '${AppText.of(context, ar: 'الموقف', en: 'Lot')}: ${activeLotName ?? activeSession!.lotId}\n'
                  '${AppText.of(context, ar: 'الفراغ', en: 'Stall')}: ${activeStallLabel ?? activeSession!.stallId}\n'
                  '${AppText.of(context, ar: 'البداية', en: 'Start')}: ${activeSession!.startTime ?? '-'}\n'
                  '${AppText.of(context, ar: 'الانتهاء', en: 'Expiry')}: ${activeSession!.expireAt ?? '-'}',
              icon: Icons.local_parking_rounded,
              color: palette.available,
              action: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed: onViewActiveSession,
                    child: Text(
                      AppText.of(context, ar: 'عرض', en: 'View'),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: onEndSession,
                    child: Text(
                      AppText.of(context, ar: 'إنهاء', en: 'End'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          DriverSectionTitle(
            AppText.of(context, ar: 'ملخص سريع', en: 'Quick summary'),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              DriverMetricTile(
                title: AppText.of(context,
                    ar: 'المواقف الفارغة', en: 'Free spots'),
                value: '$totalFree',
                icon: Icons.check_circle_outline_rounded,
                color: palette.available,
              ),
              DriverMetricTile(
                title: AppText.of(context, ar: 'المشغول', en: 'Occupied'),
                value: '$totalOccupied',
                icon: Icons.block_rounded,
                color: palette.occupied,
              ),
              DriverMetricTile(
                title: AppText.of(context, ar: 'أقرب موقف', en: 'Nearest lot'),
                value: nearestLotLabel,
                icon: Icons.place_outlined,
                color: palette.primary,
              ),
              DriverMetricTile(
                title: AppText.of(context, ar: 'المفضلة', en: 'Favorites'),
                value: '$favoriteCount',
                icon: Icons.favorite_border_rounded,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 18),
          DriverSectionTitle(
            AppText.of(context, ar: 'وصول سريع', en: 'Quick access'),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              FilledButton.icon(
                onPressed: onOpenLots,
                icon: const Icon(Icons.map_outlined),
                label: Text(AppText.of(context, ar: 'المواقف', en: 'Lots')),
              ),
              OutlinedButton.icon(
                onPressed: onOpenSessions,
                icon: const Icon(Icons.timer_outlined),
                label: Text(AppText.of(context, ar: 'حجوزاتي', en: 'Bookings')),
              ),
              OutlinedButton.icon(
                onPressed: onOpenFavorites,
                icon: const Icon(Icons.favorite_border_rounded),
                label:
                    Text(AppText.of(context, ar: 'المفضلة', en: 'Favorites')),
              ),
              OutlinedButton.icon(
                onPressed: onOpenProfile,
                icon: const Icon(Icons.person_outline_rounded),
                label: Text(AppText.of(context, ar: 'الحساب', en: 'Profile')),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DriverSectionTitle(
            AppText.of(context, ar: 'الإعلانات', en: 'Announcements'),
          ),
          const SizedBox(height: 10),
          if (announcements.isEmpty)
            DriverEmptyState(
              title: AppText.of(context,
                  ar: 'لا توجد إعلانات', en: 'No announcements'),
              body: AppText.of(
                context,
                ar: 'أي إعلان صالح سيظهر هنا.',
                en: 'Any active announcement will appear here.',
              ),
              icon: Icons.campaign_outlined,
            )
          else
            ...announcements.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DriverAnnouncementCard(announcement: item),
              ),
            ),
          const SizedBox(height: 18),
          DriverSectionTitle(
            AppText.of(context, ar: 'المواقف القريبة', en: 'Nearby lots'),
            trailing: TextButton(
              onPressed: onOpenLots,
              child: Text(
                AppText.of(context, ar: 'الكل', en: 'View all'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (nearbyLots.isEmpty)
            DriverEmptyState(
              title: AppText.of(context,
                  ar: 'لا توجد مواقف الآن', en: 'No lots available'),
              body: AppText.of(
                context,
                ar: 'اسحب للتحديث أو تحقق من الاتصال.',
                en: 'Pull to refresh or check the connection.',
              ),
              icon: Icons.map_outlined,
            )
          else
            ...nearbyLots.take(3).map((lot) {
              final live = liveLots[lot.id] ??
                  DriverLiveLot(
                    lotId: lot.id,
                    free: 0,
                    occupied: 0,
                    total: 0,
                    degradedMode: false,
                    ts: null,
                    stalls: const {},
                  );
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DriverLotCard(
                  lot: lot,
                  live: live,
                  isFavorite: favoriteLotIds.contains(lot.id),
                  onTap: () => onOpenLot(lot.id),
                  onToggleFavorite: () => onToggleFavorite(lot.id),
                ),
              );
            }),
        ],
      ),
    );
  }
}
