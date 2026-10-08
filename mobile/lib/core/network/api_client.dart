import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../routes/app_router.dart';
import '../storage/token_storage.dart';

/// Se lanza cuando el servidor bloquea el acceso del usuario:
/// - HTTP 402: la suscripción de la empresa no está vigente.
/// - HTTP 403 con código "empresa_no_habilitada": la empresa está pendiente
///   de activación o inactiva.
class AccessBlockedException implements Exception {
  AccessBlockedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Se lanza cuando la sesión venció y no se pudo renovar. La app ya
/// redirigió al login, por eso las pantallas la tratan igual que un bloqueo.
class SessionExpiredException extends AccessBlockedException {
  SessionExpiredException() : super('Tu sesión expiró. Inicia sesión nuevamente.');
}

/// Nombre anterior, se mantiene para las pantallas que ya lo usan.
typedef SubscriptionInactiveException = AccessBlockedException;

class ApiClient {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static const Duration _timeout = Duration(seconds: 20);

  /// Evita pedir varios refresh a la vez cuando muchas peticiones fallan juntas.
  static Future<bool>? _refreshing;

  final TokenStorage _storage = TokenStorage();

  /// Devuelve el token de acceso guardado (lo usan los servicios de roles y bitácora).
  Future<String?> getAccessToken() async {
    return _storage.getAccessToken();
  }

  Uri _uri(String endpoint) => Uri.parse('$baseUrl$endpoint');

  Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ---------------------------------------------------------------------------
  // Métodos públicos
  // ---------------------------------------------------------------------------

  /// POST sin autenticación (login, registro, logout).
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await _send('POST', endpoint, body: body, auth: false);
    return _decodeMap(response);
  }

  /// GET autenticado que devuelve una lista. El parámetro [token] se mantiene
  /// por compatibilidad: siempre se usa el token guardado más reciente.
  Future<List<dynamic>> getList(
    String endpoint,
    String token,
  ) async {
    final response = await _send('GET', endpoint);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception('Error al obtener datos');
  }

  /// GET autenticado que devuelve un objeto.
  Future<Map<String, dynamic>> getMap(
    String endpoint,
    String token,
  ) async {
    final response = await _send('GET', endpoint);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Error al obtener datos');
  }

  Future<Map<String, dynamic>> postAuth(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await _send('POST', endpoint, body: body);
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> putAuth(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await _send('PUT', endpoint, body: body);
    return _decodeMap(response);
  }

  Future<void> deleteAuth(
    String endpoint,
  ) async {
    final response = await _send('DELETE', endpoint);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error al eliminar registro');
    }
  }

  /// Pide al servidor un nuevo par de tokens usando el refresh token guardado.
  /// Devuelve true si la sesión sigue activa.
  Future<bool> refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() {
      _refreshing = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Envío de peticiones
  // ---------------------------------------------------------------------------

  Future<http.Response> _send(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    var response = await _request(method, endpoint, body: body, auth: auth);

    // El token de acceso venció: se renueva y se repite la petición una vez.
    if (auth && response.statusCode == 401) {
      if (await refreshSession()) {
        response = await _request(method, endpoint, body: body, auth: auth);
      }
      if (response.statusCode == 401) {
        await _expireSession();
      }
    }

    await _checkAccess(response);
    return response;
  }

  Future<http.Response> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    required bool auth,
  }) async {
    final token = auth ? await _storage.getAccessToken() : null;
    final uri = _uri(endpoint);
    final headers = _headers(token: token);
    final encoded = body == null ? null : jsonEncode(body);

    final Future<http.Response> future;
    if (method == 'POST') {
      future = http.post(uri, headers: headers, body: encoded);
    } else if (method == 'PUT') {
      future = http.put(uri, headers: headers, body: encoded);
    } else if (method == 'DELETE') {
      future = http.delete(uri, headers: headers);
    } else {
      future = http.get(uri, headers: headers);
    }

    try {
      final response = await future.timeout(_timeout);
      _logResponse(response);
      return response;
    } on TimeoutException {
      throw http.ClientException('No se pudo conectar con el servidor.', uri);
    }
  }

  Future<bool> _doRefresh() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh == null) {
      return false;
    }

    final http.Response response;
    try {
      response = await _request(
        'POST',
        'auth/refresh/',
        body: {'refresh': refresh},
        auth: false,
      );
    } catch (_) {
      // Sin conexión: no se puede confirmar la sesión.
      return false;
    }

    // Suscripción vencida o empresa no habilitada: redirige y lanza.
    await _checkAccess(response);

    if (response.statusCode == 401) {
      // La sesión fue cerrada o venció en el servidor.
      await _storage.clearTokens();
      return false;
    }

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await _storage.saveTokens(
      access: data['access'] as String,
      refresh: data['refresh'] as String,
    );
    if (data['user'] is Map<String, dynamic>) {
      await _storage.saveUser(data['user'] as Map<String, dynamic>);
    }
    return true;
  }

  Future<void> _expireSession() async {
    await _storage.clearTokens();
    AppRouter.router.go('/login');
    throw SessionExpiredException();
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) {
        return <String, dynamic>{};
      }
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }
      return <String, dynamic>{'data': data};
    }

    throw Exception(response.body);
  }

  // ---------------------------------------------------------------------------
  // Bloqueos del modelo SaaS
  // ---------------------------------------------------------------------------

  /// Si el servidor bloquea el acceso (suscripción vencida o empresa no
  /// habilitada) se cierra la sesión y se muestra la pantalla informativa.
  Future<void> _checkAccess(http.Response response) async {
    final code = _extractCode(response.body);

    String? title;
    if (response.statusCode == 402) {
      title = 'Suscripción no vigente';
    } else if (response.statusCode == 403 && code == 'empresa_no_habilitada') {
      title = 'Empresa no habilitada';
    }

    if (title == null) {
      return;
    }

    final message = _extractMessage(response.body) ??
        'Su empresa no puede usar el sistema en este momento.';

    await _storage.clearTokens();
    AppRouter.router.go(
      '/acceso-bloqueado',
      extra: {'titulo': title, 'mensaje': message},
    );

    throw AccessBlockedException(message);
  }

  Map<String, dynamic>? _errorBlock(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
        return data['error'] as Map<String, dynamic>;
      }
    } catch (_) {
      // El cuerpo no es JSON.
    }
    return null;
  }

  String? _extractMessage(String body) {
    final error = _errorBlock(body);
    if (error != null && error['message'] is String) {
      return error['message'] as String;
    }
    return null;
  }

  String? _extractCode(String body) {
    final error = _errorBlock(body);
    final details = error?['details'];
    if (details is Map<String, dynamic> && details['code'] is String) {
      return details['code'] as String;
    }
    return null;
  }

  void _logResponse(http.Response response) {
    if (!kDebugMode) return;
    debugPrint('URL: ${response.request?.url}');
    debugPrint('STATUS: ${response.statusCode}');
    final bodyPreview = response.body.length > 500 ? response.body.substring(0, 500) : response.body;
    debugPrint('BODY: $bodyPreview');
  }
}