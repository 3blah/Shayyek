import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../config.dart';

class DriverSearchPlace {
  const DriverSearchPlace({
    required this.title,
    required this.subtitle,
    required this.point,
  });

  final String title;
  final String subtitle;
  final LatLng point;
}

class DriverRoutePath {
  const DriverRoutePath({
    required this.points,
    this.distanceMeters,
    this.durationSeconds,
    this.isFallback = false,
    this.notice,
  });

  final List<LatLng> points;
  final double? distanceMeters;
  final double? durationSeconds;
  final bool isFallback;
  final String? notice;
}

class DriverNavigationService {
  DriverNavigationService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const String _nominatimSearchUrl =
      'https://nominatim.openstreetmap.org/search';
  static const String _orsDirectionsUrl =
      'https://api.openrouteservice.org/v2/directions/driving-car/geojson';

  Future<List<DriverSearchPlace>> searchPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const <DriverSearchPlace>[];
    }

    final uri = Uri.parse(_nominatimSearchUrl).replace(
      queryParameters: <String, String>{
        'q': cleanQuery,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '5',
      },
    );

    final response = await _client.get(
      uri,
      headers: _defaultHeaders(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Search request failed with ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const <DriverSearchPlace>[];
    }

    return decoded
        .whereType<Map>()
        .map((entry) => _mapSearchPlace(entry.cast<String, dynamic>()))
        .whereType<DriverSearchPlace>()
        .toList();
  }

  Future<DriverRoutePath> buildRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final apiKey = AppServiceConfig.openRouteServiceApiKey.trim();
    if (apiKey.isNotEmpty) {
      final orsRoute = await _tryOpenRouteServiceRoute(
        apiKey: apiKey,
        origin: origin,
        destination: destination,
      );
      if (orsRoute != null) {
        return orsRoute;
      }
    }

    final osrmRoute = await _tryOsrmRoute(
      origin: origin,
      destination: destination,
    );
    if (osrmRoute != null) {
      return osrmRoute;
    }

    return DriverRoutePath(
      points: <LatLng>[origin, destination],
      distanceMeters:
          const Distance().as(LengthUnit.Meter, origin, destination),
      durationSeconds: null,
      isFallback: true,
      notice:
          'Real road routing is unavailable right now, so a direct fallback line is used.',
    );
  }

  Future<DriverRoutePath?> _tryOpenRouteServiceRoute({
    required String apiKey,
    required LatLng origin,
    required LatLng destination,
  }) async {
    final response = await _client
        .post(
      Uri.parse(_orsDirectionsUrl),
      headers: <String, String>{
        ..._defaultHeaders(),
        'Authorization': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'coordinates': <List<double>>[
          <double>[origin.longitude, origin.latitude],
          <double>[destination.longitude, destination.latitude],
        ],
        'instructions': false,
      }),
    )
        .timeout(const Duration(seconds: 10), onTimeout: () {
      return http.Response('', 504);
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final features = decoded['features'];
    if (features is! List || features.isEmpty) {
      return null;
    }

    final feature = features.first;
    if (feature is! Map<String, dynamic>) {
      return null;
    }

    final geometry = feature['geometry'];
    final properties = feature['properties'];
    final summary =
        properties is Map<String, dynamic> ? properties['summary'] : null;

    final points = _decodeGeoJsonCoordinates(
      geometry is Map<String, dynamic> ? geometry['coordinates'] : null,
    );

    if (points.length < 2) {
      return null;
    }

    return DriverRoutePath(
      points: points,
      distanceMeters: summary is Map<String, dynamic>
          ? _asDouble(summary['distance'])
          : null,
      durationSeconds: summary is Map<String, dynamic>
          ? _asDouble(summary['duration'])
          : null,
    );
  }

  Future<DriverRoutePath?> _tryOsrmRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final uri = Uri.parse(
      '${AppServiceConfig.osrmRouteServiceUrl}/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}',
    ).replace(
      queryParameters: const <String, String>{
        'overview': 'full',
        'geometries': 'geojson',
      },
    );

    final response = await _client
        .get(
      uri,
      headers: _defaultHeaders(),
    )
        .timeout(const Duration(seconds: 10), onTimeout: () {
      return http.Response('', 504);
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      return null;
    }

    final route = routes.first;
    if (route is! Map<String, dynamic>) {
      return null;
    }

    final geometry = route['geometry'];
    final points = _decodeGeoJsonCoordinates(
      geometry is Map<String, dynamic> ? geometry['coordinates'] : null,
    );
    if (points.length < 2) {
      return null;
    }

    return DriverRoutePath(
      points: points,
      distanceMeters: _asDouble(route['distance']),
      durationSeconds: _asDouble(route['duration']),
      notice: 'Road route loaded from the fallback routing service.',
    );
  }

  DriverSearchPlace? _mapSearchPlace(Map<String, dynamic> raw) {
    final lat = _asDouble(raw['lat']);
    final long = _asDouble(raw['lon']);
    if (lat == null || long == null) {
      return null;
    }

    final title = _nonEmpty(raw['name']) ??
        _nonEmpty(raw['display_name']) ??
        'Pinned place';
    final subtitle = _nonEmpty(raw['display_name']) ?? title;
    return DriverSearchPlace(
      title: title,
      subtitle: subtitle,
      point: LatLng(lat, long),
    );
  }

  List<LatLng> _decodeGeoJsonCoordinates(dynamic coordinates) {
    if (coordinates is! List) {
      return const <LatLng>[];
    }

    final points = <LatLng>[];
    for (final item in coordinates) {
      if (item is! List || item.length < 2) {
        continue;
      }
      final long = _asDouble(item[0]);
      final lat = _asDouble(item[1]);
      if (lat == null || long == null) {
        continue;
      }
      points.add(LatLng(lat, long));
    }
    return points;
  }

  Map<String, String> _defaultHeaders() {
    return <String, String>{
      'User-Agent': AppServiceConfig.openStreetMapUserAgent,
      'Accept': 'application/json',
    };
  }
}

String? _nonEmpty(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

double? _asDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '');
}
