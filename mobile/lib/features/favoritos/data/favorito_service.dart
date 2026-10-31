import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../catalogo/models/product.dart';

/// Favoritos del turista: misma tabla que la web, así que se ven en ambas.
class FavoritoService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  /// Ids marcados, compartidos por todos los corazones de la app.
  static final ValueNotifier<Set<int>> ids = ValueNotifier<Set<int>>(<int>{});
  static bool _cargados = false;

  Future<String> _getToken() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      throw Exception('No existe token');
    }
    return token;
  }

  Future<List<Product>> getFavoritos() async {
    final token = await _getToken();
    final data = await _apiClient.getList('favoritos/', token);
    final productos = data.map((json) => Product.fromJson(json as Map<String, dynamic>)).toList();
    final union = {...ids.value, ...productos.map((p) => p.id)};
    // Solo avisa si cambió, para no recargar las pantallas sin necesidad.
    if (union.length != ids.value.length) ids.value = union;
    return productos;
  }

  /// Carga los ids una vez por sesión (o siempre con [forzar]).
  Future<void> cargarIds({bool forzar = false}) async {
    if (_cargados && !forzar) return;
    final token = await _getToken();
    final data = await _apiClient.getMap('favoritos/ids/', token);
    ids.value = (data['ids'] as List<dynamic>? ?? []).map((e) => e as int).toSet();
    _cargados = true;
  }

  Future<void> marcar(int productoId) async {
    await _apiClient.putAuth('favoritos/$productoId/', {});
    ids.value = {...ids.value, productoId};
  }

  Future<void> quitar(int productoId) async {
    await _apiClient.deleteAuth('favoritos/$productoId/');
    ids.value = {...ids.value}..remove(productoId);
  }

  /// Al cerrar sesión: la próxima cuenta carga sus propios favoritos.
  static void limpiar() {
    ids.value = <int>{};
    _cargados = false;
  }
}