import 'dart:convert';

/// Convierte un error del servidor en un mensaje legible para el usuario.
///
/// El backend responde con el formato:
/// {"error": {"status": 400, "message": "...", "details": {"campo": ["..."]}}}
String apiErrorMessage(Object error) {
  final raw = error.toString().replaceFirst('Exception: ', '');

  if (raw.contains('SocketException') || raw.contains('ClientException')) {
    return 'No se pudo conectar con el servidor. Revisa tu conexión a internet.';
  }

  try {
    final data = jsonDecode(raw);
    if (data is Map<String, dynamic>) {
      final err = data['error'];
      if (err is Map<String, dynamic>) {
        final details = err['details'];
        if (details is Map<String, dynamic>) {
          for (final entry in details.entries) {
            if (entry.key == 'code') continue;
            final value = entry.value;
            if (value is List && value.isNotEmpty) return value.first.toString();
            if (value is String) return value;
          }
        }
        if (err['message'] is String) return err['message'] as String;
      }
    }
  } catch (_) {
    // No es JSON: se devuelve el texto original.
  }
  return raw;
}