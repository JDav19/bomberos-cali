import 'package:firebase_core/firebase_core.dart';

/// Valores inyectados en compilacion con
/// `--dart-define-from-file=config/app_config.json` (archivo ignorado por git).
/// Los nombres estan en `config/app_config.example.json`.
abstract final class AppConfig {
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const cloudinaryCloud = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const cloudinaryPreset = String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');
  static const agoraAppId = String.fromEnvironment('AGORA_APP_ID');
  static const agoraTempToken = String.fromEnvironment('AGORA_TEMP_TOKEN');
  static const agoraCertificado = String.fromEnvironment('AGORA_APP_CERTIFICATE');

  static const _placeholder = 'PEGUE_AQUI';

  static bool _ok(String v) => v.isNotEmpty && !v.contains(_placeholder);

  static bool get firebaseListo =>
      _ok(firebaseApiKey) && _ok(firebaseAppId) && _ok(firebaseSenderId) && _ok(firebaseProjectId);
  static bool get cloudinaryListo => _ok(cloudinaryCloud) && _ok(cloudinaryPreset);
  static bool get agoraListo => _ok(agoraAppId);

  /// Nombres de las variables que faltan para que la app funcione.
  static List<String> faltantes() => [
        if (!_ok(firebaseApiKey)) 'FIREBASE_API_KEY',
        if (!_ok(firebaseAppId)) 'FIREBASE_APP_ID',
        if (!_ok(firebaseSenderId)) 'FIREBASE_MESSAGING_SENDER_ID',
        if (!_ok(firebaseProjectId)) 'FIREBASE_PROJECT_ID',
      ];

  static FirebaseOptions get firebaseOptions => const FirebaseOptions(
        apiKey: firebaseApiKey,
        appId: firebaseAppId,
        messagingSenderId: firebaseSenderId,
        projectId: firebaseProjectId,
      );

  static const lineaEmergencia = '119';
}
