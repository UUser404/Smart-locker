import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

const String _kPrefPetugasId = 'petugas_id';

/// Handler ini WAJIB berupa top-level function (bukan method di class),
/// dipanggil sistem saat notifikasi masuk ketika app di-background/terminated.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // System tray notif otomatis ditangani FCM kalau payload punya block
  // "notification". Cukup log kalau perlu debug.
}

class FcmService {
  final ApiService _api;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Static flag: pastikan listener `onTokenRefresh` cuma didaftarkan 1x
  /// selama lifetime app (biar tidak menumpuk saat initAndRegister dipanggil
  /// berkali-kali: login + startup + dst).
  static bool _refreshListenerBound = false;

  FcmService(this._api);

  Future<String?> getSavedPetugasId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrefPetugasId);
  }

  Future<void> _savePetugasId(String petugasId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefPetugasId, petugasId);
  }

  Future<void> initAndRegister(String petugasId) async {
    await _savePetugasId(petugasId);

    // Minta izin (iOS & Android 13+)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Ambil token & register
    final token = await _messaging.getToken();
    if (token != null) {
      await _api.registerDevice(fcmToken: token, petugasId: petugasId);
    }

    // Bind listener onTokenRefresh HANYA SEKALI
    if (!_refreshListenerBound) {
      _refreshListenerBound = true;
      _messaging.onTokenRefresh.listen((newToken) async {
        final savedId = await getSavedPetugasId();
        if (savedId != null) {
          await _api.registerDevice(fcmToken: newToken, petugasId: savedId);
        }
      });
    }
  }

  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
}
