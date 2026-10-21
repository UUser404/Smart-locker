import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

const String _kPrefPetugasId = 'petugas_id';

/// Handler ini WAJIB berupa top-level function (bukan method di class),
/// dipanggil sistem saat notifikasi masuk ketika app di-background/terminated.
///
/// `@pragma('vm:entry-point')` WAJIB ada sejak Dart 3.x + Impeller/AOT:
/// tanpa anotasi ini, tree-shaker membuang function → crash saat FCM
/// mencoba panggil dari native code:
/// "To closurize ... from native code, it must be annotated."
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // System tray notif otomatis ditangani FCM kalau payload punya block
  // "notification". Cukup log kalau perlu debug.
  debugPrint('[FCM background] ${message.messageId}');
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

  /// Unregister device saat logout:
  /// 1. Hapus token dari backend (butuh JWT yang masih valid).
  /// 2. Invalidasi token FCM lokal supaya device berhenti terima notif.
  /// 3. Hapus `petugas_id` lokal supaya onTokenRefresh tidak re-register.
  ///
  /// Aman dipanggil meski backend gagal (mis. JWT expired) — token yatim
  /// di Firestore akan dibersihkan otomatis oleh cleanup di fcmService.js
  /// saat FCM lapor `registration-token-not-registered`.
  Future<void> unregister() async {
    // 1. Ambil token & hapus dari backend
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _api.unregisterDevice(fcmToken: token);
      }
    } catch (e) {
      debugPrint('[FCM] unregister backend gagal: $e');
    }

    // 2. Invalidasi token di FCM
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('[FCM] deleteToken gagal: $e');
    }

    // 3. Hapus petugas_id lokal
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefPetugasId);
  }

  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
}
