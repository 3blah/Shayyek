import 'package:flutter/material.dart';

import '../../app_text.dart';
import '../services/driver_task_service.dart';
import '../ui/driver_shared_widgets.dart';

class DriverFavoritesPage extends StatelessWidget {
  const DriverFavoritesPage({
    super.key,
    required this.favoriteLots,
    required this.liveLots,
    required this.favoriteLotIds,
    required this.onRefresh,
    required this.onOpenLot,
    required this.onToggleFavorite,
  });

  final List<DriverLot> favoriteLots;
  final Map<String, DriverLiveLot> liveLots;
  final Set<String> favoriteLotIds;
  final Future<void> Function() onRefresh;
  final void Function(String lotId) onOpenLot;
  final void Function(String lotId) onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          DriverTopHeader(
            title: AppText.of(context, ar: 'المفضلة', en: 'Favorites'),
            subtitle: AppText.of(
              context,
              ar: 'مرتبطة مباشرة بالمستخدم الحالي فقط.',
              en: 'Linked only to the current user.',
            ),
            icon: Icons.favorite_rounded,
          ),
          const SizedBox(height: 18),
          if (favoriteLots.isEmpty)
            DriverEmptyState(
              title: AppText.of(context,
                  ar: 'لا توجد مواقف مفضلة', en: 'No favorite lots'),
              body: AppText.of(
                context,
                ar: 'يمكنك إضافة أي موقف من صفحة المواقف للوصول السريع لاحقاً.',
                en: 'You can add any lot from the lots page for quick access later.',
              ),
              icon: Icons.favorite_border_rounded,
            )
          else
            ...favoriteLots.map(
              (lot) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DriverLotCard(
                  lot: lot,
                  live: liveLots[lot.id] ??
                      DriverLiveLot(
                        lotId: lot.id,
                        free: 0,
                        occupied: 0,
                        total: 0,
                        degradedMode: false,
                        ts: null,
                        stalls: const {},
                      ),
                  isFavorite: favoriteLotIds.contains(lot.id),
                  onTap: () => onOpenLot(lot.id),
                  onToggleFavorite: () => onToggleFavorite(lot.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
