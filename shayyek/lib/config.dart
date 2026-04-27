import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBNhuW2ran5pM_K90i-a2m9y6o3j6SI5gI',
        appId: '1:488386682748:android:99c4ab15bb42296a964ef9',
        messagingSenderId: '488386682748',
        projectId: 'smartpasrk',
        storageBucket: 'smartpasrk.firebasestorage.app',
        databaseURL: 'https://smartpasrk-default-rtdb.firebaseio.com',
      ),
    );
  }
}

class AppServiceConfig {
  const AppServiceConfig._();

  static const String openRouteServiceApiKey =
      String.fromEnvironment('ORS_API_KEY', defaultValue: '');
  static const String osrmRouteServiceUrl = String.fromEnvironment(
    'OSRM_ROUTE_URL',
    defaultValue: 'https://router.project-osrm.org/route/v1/driving',
  );
  static const String openStreetMapUserAgent = String.fromEnvironment(
    'OSM_USER_AGENT',
    defaultValue: 'com.example.shayyek.mobile',
  );
  static const String cameraBridgeBaseUrl =
      String.fromEnvironment('CAMERA_BRIDGE_URL', defaultValue: '');
  static const String parkingAiBridgeBaseUrl = String.fromEnvironment(
    'PARKING_AI_BRIDGE_URL',
    defaultValue: 'http://192.168.8.17:8000',
  );
}
