import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/notificacion.dart';

/// Filtros de la bandeja (pestañas).
enum FiltroNotificaciones {
  todas(null),
  noLeidas('no_leidas'),
  recordatorios('recordatorios');

  const FiltroNotificaciones(this.valor);

  final String? valor;
}

/// Llamadas del CU45 (notificaciones y recordatorios) al backend.
class NotificacionService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  /// Contador compartido: lo muestra la campana y lo actualiza la bandeja.
  static final ValueNotifier<int> noLeidas = ValueNotifier<int>(0);

  Future<String> _getToken() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      throw Exception('No existe token');
    }
    return token;
  }

  Future<({List<Notificacion> resultados, bool haySiguiente})> getNotificaciones({
    FiltroNotificaciones filtro = FiltroNotificaciones.todas,
    int page = 1,
  }) async {
    final token = await _getToken();
    final params = <String, String>{
      'page': '$page',
      if (filtro.valor != null) 'filtro': filtro.valor!,
    };
    final data = await _apiClient.getMap('notificaciones/?${Uri(queryParameters: params).query}', token);
    final resultados = (data['results'] as List<dynamic>? ?? [])
        .map((item) => Notificacion.fromJson(item as Map<String, dynamic>))
        .toList();
    return (resultados: resultados, haySiguiente: data['next'] != null);
  }

  /// Consulta el contador de no leídas y actualiza la campana.
  Future<int> refrescarContador() async {
    final token = await _getToken();
    final data = await _apiClient.getMap('notificaciones/no-leidas/', token);
    final total = (data['no_leidas'] as int?) ?? 0;
    noLeidas.value = total;
    return total;
  }

  Future<Notificacion> marcarLeida(int id) async {
    final data = await _apiClient.postAuth('notificaciones/$id/leer/', {});
    final notificacion = Notificacion.fromJson(data);
    await _refrescarEnSilencio();
    return notificacion;
  }

  Future<void> marcarTodasLeidas() async {
    await _apiClient.postAuth('notificaciones/leer-todas/', {});
    noLeidas.value = 0;
  }

  Future<void> eliminar(int id) async {
    await _apiClient.deleteAuth('notificaciones/$id/');
    await _refrescarEnSilencio();
  }

  Future<void> eliminarLeidas() async {
    await _apiClient.postAuth('notificaciones/limpiar-leidas/', {});
  }

  Future<void> _refrescarEnSilencio() async {
    try {
      await refrescarContador();
    } catch (_) {
      // El contador se corrige en la siguiente consulta de la campana.
    }
  }
}