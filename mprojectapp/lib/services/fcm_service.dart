import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

const String _kPrefPetugasId = 'petugas_id';

/// Handler ini WAJIB berupa top-level function (bukan method di class),
/// dipanggil sistem saat notifikasi masuk ketika app di-background/terminated.
/// Daftarkan lewat FirebaseMessaging.onBackgroundMessage di main().
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Cukup log di sini; tampilan notifikasi system-tray sudah otomatis
  // ditangani FCM selama payload berisi block "notification".
  // print('Background message: ${message.messageId}');
}

class FcmService {
  final ApiService _api;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  FcmService(this._api);

  /// Ambil nama/NIP petugas yang tersimpan lokal, kalau ada.
  Future<String?> getSavedPetugasId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrefPetugasId);
  }

  Future<void> _savePetugasId(String petugasId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefPetugasId, petugasId);
  }

  /// Panggil sekali saat app dibuka pertama kali / login (masih tanpa
  /// autentikasi penuh sesuai draft dokumen — cukup identitas petugas).
  /// Minta izin notifikasi, ambil token FCM, lalu daftarkan ke backend.
  Future<void> initAndRegister(String petugasId) async {
    await _savePetugasId(petugasId);

    // iOS & Android 13+ butuh permintaan izin eksplisit.
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await _messaging.getToken();
    if (token != null) {
      await _api.registerDevice(fcmToken: token, petugasId: petugasId);
    }

    // Kalau token berubah (reinstall, clear data, dll), daftar ulang otomatis.
    _messaging.onTokenRefresh.listen((newToken) async {
      final savedId = await getSavedPetugasId();
      if (savedId != null) {
        await _api.registerDevice(fcmToken: newToken, petugasId: savedId);
      }
    });
  }

  /// Stream pesan yang diterima saat app sedang dibuka (foreground).
  /// Backend mengirim data: { locker_id } saat locker jadi needs_attention.
  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  /// Stream saat user tap notifikasi dan app dibuka dari background.
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
}
