import 'package:flutter/foundation.dart';

/// Configuración de la app según el entorno.
///
/// La URL del servidor NO se escribe en el código: se inyecta al compilar.
///   Desarrollo: flutter run --dart-define-from-file=config/env.dev.json
///   Producción: flutter build apk --release --dart-define-from-file=config/env.prod.json
class AppConfig {
  AppConfig._();

  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiBaseUrl.isEmpty) {
      throw StateError(
        'No se definió API_BASE_URL. Ejecute la app con '
        '--dart-define-from-file=config/env.prod.json',
      );
    }

    final uri = Uri.tryParse(_apiBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL no es una URL válida: $_apiBaseUrl');
    }

    // En la versión publicada solo se permite conexión cifrada con la nube.
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('En producción API_BASE_URL debe usar HTTPS.');
    }

    return _apiBaseUrl.endsWith('/') ? _apiBaseUrl : '$_apiBaseUrl/';
  }
}