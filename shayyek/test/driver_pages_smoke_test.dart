import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shayyek/driver/pages/driver_dashboard_page.dart';
import 'package:shayyek/driver/pages/driver_favorites_page.dart';
import 'package:shayyek/driver/pages/driver_map_page.dart';
import 'package:shayyek/driver/pages/driver_notifications_page.dart';
import 'package:shayyek/driver/pages/driver_profile_page.dart';
import 'package:shayyek/driver/pages/driver_sessions_page.dart';
import 'package:shayyek/driver/services/driver_task_service.dart';
import 'package:shayyek/theme_controller.dart';

void main() {
  const user = DriverUserContext(
    userKey: 'user_001',
    primaryUserId: 'user_001',
    appUserId: 'user_001',
    name: 'سائق تجريبي',
    email: 'driver@example.com',
    phone: '0500000000',
    roleId: 'role_003',
    roleName: 'driver',
    status: 'active',
  );

  final preferences = DriverPreferences.defaults(userId: user.primaryUserId);
  const lot = DriverLot(
    id: 'lot_001',
    name: 'Lot A',
    address: 'Jazan, Saudi Arabia',
    hours: 'Sun-Thu 08:00-22:00',
    currency: 'SAR',
    rateHou: 2.5,
    maxStay: 240,
    lat: 16.88,
    long: 42.55,
    distanceKm: 1.2,
  );

  final liveLot = DriverLiveLot(
    lotId: lot.id,
    free: 2,
    occupied: 1,
    total: 3,
    degradedMode: false,
    ts: '2026-03-28T12:00:00Z',
    stalls: const {},
  );

  final freeStall = DriverStall(
    id: 'stall_001',
    lotId: lot.id,
    label: 'A-01',
    state: 'free',
    currency: 'SAR',
    rateHou: 2.5,
    maxStay: 240,
    accessible: true,
    ev: false,
    reserved: false,
    lastSeen: '2026-03-28T12:00:00Z',
    confidence: 0.96,
  );

  final session = DriverSession(
    id: 'session_001',
    userId: user.primaryUserId,
    lotId: lot.id,
    stallId: freeStall.id,
    status: 'active',
    lat: lot.lat,
    long: lot.long,
    timeAlertSent: false,
    navAutoReroute: true,
    targetStallId: freeStall.id,
    startTime: '2026-03-28T10:00:00Z',
    expireAt: '2026-03-28T14:00:00Z',
    parkedLat: lot.lat,
    parkedLong: lot.long,
    parkedSavedAt: '2026-03-28T10:02:00Z',
  );

  final notification = DriverNotificationItem(
    id: 'notif_001',
    type: 'time_expiry',
    title: 'Parking time reminder',
    body: 'ستنتهي الجلسة قريبًا.',
    channel: 'push',
    status: 'sent',
    userId: user.primaryUserId,
    sessionId: session.id,
    lotId: lot.id,
    stallId: freeStall.id,
    createdAt: '2026-03-28T12:10:00Z',
  );

  Widget wrap(Widget child) {
    final controller = ThemeController();
    return MaterialApp(
      locale: const Locale('ar'),
      home: ThemeScope(
        controller: controller,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  testWidgets('Driver dashboard page builds', (tester) async {
    await tester.pumpWidget(
      wrap(
        DriverDashboardPage(
          user: user,
          nearbyLots: const [lot],
          liveLots: {lot.id: liveLot},
          favoriteLotIds: {lot.id},
          announcements: const [],
          activeSession: session,
          activeLotName: lot.name,
          activeStallLabel: freeStall.label,
          totalFree: liveLot.free,
          totalOccupied: liveLot.occupied,
          nearestLotLabel: lot.name,
          favoriteCount: 1,
          onRefresh: () async {},
          onOpenLots: () {},
          onOpenNotifications: () {},
          onOpenSessions: () {},
          onOpenFavorites: () {},
          onOpenProfile: () {},
          onOpenLot: (_) {},
          onToggleFavorite: (_) {},
          onViewActiveSession: () {},
          onEndSession: () {},
        ),
      ),
    );

    expect(find.byType(DriverDashboardPage), findsOneWidget);
    expect(find.text(lot.name), findsWidgets);
  });

  testWidgets('Driver map page builds', (tester) async {
    await tester.pumpWidget(
      wrap(
        DriverMapPage(
          lots: const [lot],
          selectedLotId: lot.id,
          liveLots: {lot.id: liveLot},
          selectedLotCameras: const [],
          favoriteLotIds: const {},
          preferences: preferences,
          stalls: [freeStall],
          announcements: const [],
          currentLat: 16.87,
          currentLong: 42.54,
          showTileLayer: false,
          onRefresh: () async {},
          onSelectLot: (_) {},
          onToggleFavorite: (_) {},
          onUpdatePreferences: (_) async {},
          onNavigateToStall: (_, __) async {},
        ),
      ),
    );

    expect(find.byType(DriverMapPage), findsOneWidget);
    expect(find.text(lot.name), findsWidgets);
  });

  testWidgets('Driver sessions page builds', (tester) async {
    await tester.pumpWidget(
      wrap(
        DriverSessionsPage(
          now: DateTime.utc(2026, 3, 28, 12),
          activeSession: session,
          navigatingSession: null,
          completedSessions: const [],
          lotNameOf: (_) => lot.name,
          lotAddressOf: (_) => lot.address,
          stallLabelOf: (_) => freeStall.label,
          onRefresh: () async {},
          onConfirmParking: () async {},
          onEndSession: () async {},
          onSaveParkedPin: () async {},
          onShareInvoice: (_) async {},
        ),
      ),
    );

    expect(find.byType(DriverSessionsPage), findsOneWidget);
  });

  testWidgets('Driver notifications page builds', (tester) async {
    await tester.pumpWidget(
      wrap(
        DriverNotificationsPage(
          notifications: [notification],
          readIds: const {},
          onRefresh: () async {},
          onMarkRead: (_) {},
        ),
      ),
    );

    expect(find.byType(DriverNotificationsPage), findsOneWidget);
    expect(find.text(notification.title), findsOneWidget);
  });

  testWidgets('Driver favorites page builds', (tester) async {
    await tester.pumpWidget(
      wrap(
        DriverFavoritesPage(
          favoriteLots: const [lot],
          liveLots: {lot.id: liveLot},
          favoriteLotIds: {lot.id},
          onRefresh: () async {},
          onOpenLot: (_) {},
          onToggleFavorite: (_) {},
        ),
      ),
    );

    expect(find.byType(DriverFavoritesPage), findsOneWidget);
    expect(find.text(lot.name), findsOneWidget);
  });

  testWidgets('Driver profile page builds', (tester) async {
    await tester.pumpWidget(
      wrap(
        DriverProfilePage(
          user: user,
          preferences: preferences,
          onSave: ({
            required String name,
            required String phone,
            required DriverPreferences preferences,
          }) async {},
          onLogout: () async {},
        ),
      ),
    );

    expect(find.byType(DriverProfilePage), findsOneWidget);
  });
}
