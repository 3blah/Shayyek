import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shayyek/driver/services/driver_navigation_service.dart';

void main() {
  group('DriverNavigationService', () {
    test('uses a real road route from OSRM when ORS key is not configured',
        () async {
      final service = DriverNavigationService(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            contains('router.project-osrm.org/route/v1/driving'),
          );
          return http.Response(
            jsonEncode({
              'routes': [
                {
                  'distance': 1320.4,
                  'duration': 305.8,
                  'geometry': {
                    'coordinates': [
                      [42.5511, 16.8892],
                      [42.5530, 16.8900],
                      [42.5560, 16.8920],
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final route = await service.buildRoute(
        origin: LatLng(16.8892, 42.5511),
        destination: LatLng(16.8920, 42.5560),
      );

      expect(route.isFallback, isFalse);
      expect(route.points.length, greaterThan(2));
      expect(route.distanceMeters, 1320.4);
      expect(route.durationSeconds, 305.8);
    });

    test('falls back to a direct line only when no routing provider succeeds',
        () async {
      final service = DriverNavigationService(
        client: MockClient((request) async {
          return http.Response('{}', 500);
        }),
      );

      final origin = LatLng(16.8892, 42.5511);
      final destination = LatLng(16.8920, 42.5560);
      final route = await service.buildRoute(
        origin: origin,
        destination: destination,
      );

      expect(route.isFallback, isTrue);
      expect(route.points, [origin, destination]);
      expect(route.notice, isNotNull);
    });
  });
}
