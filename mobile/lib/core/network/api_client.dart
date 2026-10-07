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

/// Nombre anterior, se mantiene para las pantallas que ya lo usan.
typedef SubscriptionInactiveException = AccessBlockedException;

class ApiClient {
  static String get baseUrl => AppConfig.apiBaseUrl;

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

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    debugPrint('POST URL: ${_uri(endpoint)}');

    final response = await http.post(
      _uri(endpoint),
      headers: _headers(),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<List<dynamic>> getList(
    String endpoint,
    String token,
  ) async {
    final response = await http.get(
      _uri(endpoint),
      headers: _headers(token: token),
    );

    _logResponse(response, 300);
    await _checkAccess(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }

    throw Exception('Error al obtener datos');
  }

  Future<Map<String, dynamic>> getMap(
    String endpoint,
    String token,
  ) async {
    final response = await http.get(
      _uri(endpoint),
      headers: _headers(token: token),
    );

    _logResponse(response, 300);
    await _checkAccess(response);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Error al obtener datos');
  }

  Future<Map<String, dynamic>> postAuth(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await _storage.getAccessToken();

    final response = await http.post(
      _uri(endpoint),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> putAuth(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await _storage.getAccessToken();

    final response = await http.put(
      _uri(endpoint),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<void> deleteAuth(
    String endpoint,
  ) async {
    final token = await _storage.getAccessToken();

    final response = await http.delete(
      _uri(endpoint),
      headers: _headers(token: token),
    );

    await _checkAccess(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error al eliminar registro');
    }
  }

  Future<Map<String, dynamic>> _handleResponse(
    http.Response response,
  ) async {
    _logResponse(response, 1000);
    await _checkAccess(response);

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data as Map<String, dynamic>;
    }

    throw Exception(response.body);
  }

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

  void _logResponse(http.Response response, int maxLength) {
    debugPrint('URL: ${response.request?.url}');
    debugPrint('STATUS: ${response.statusCode}');
    final bodyPreview = response.body.length > maxLength
        ? response.body.substring(0, maxLength)
        : response.body;
    debugPrint('BODY: $bodyPreview');
  }
}