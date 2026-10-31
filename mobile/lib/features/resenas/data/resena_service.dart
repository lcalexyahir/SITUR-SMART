import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../catalogo/models/product.dart';
import '../models/resena.dart';

/// Llamadas del CU35 (calificaciones y reseñas) al backend.
class ResenaService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  Future<String> _getToken() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      throw Exception('No existe token');
    }
    return token;
  }

  /// Resumen y reseñas de un producto, de la más nueva a la más antigua.
  Future<PaginaResenas> getResenasProducto(
    int productoId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    final token = await _getToken();
    final data = await _apiClient.getMap(
      'catalogo/productos/$productoId/resenas/?page=$page&page_size=$pageSize',
      token,
    );
    return PaginaResenas.fromJson(data);
  }

  /// El turista califica el producto (una reseña por producto).
  Future<Resena> crearResena({
    required int productoId,
    required int calificacion,
    required String comentario,
  }) async {
    final data = await _apiClient.postAuth(
      'catalogo/productos/$productoId/resenas/',
      {'calificacion': calificacion, 'comentario': comentario.trim()},
    );
    return Resena.fromJson(data);
  }

  Future<Resena> editarResena({
    required int resenaId,
    required int calificacion,
    required String comentario,
  }) async {
    final data = await _apiClient.putAuth(
      'resenas/$resenaId/',
      {'calificacion': calificacion, 'comentario': comentario.trim()},
    );
    return Resena.fromJson(data);
  }

  Future<void> eliminarResena(int resenaId) async {
    await _apiClient.deleteAuth('resenas/$resenaId/');
  }

  /// Reseñas que escribió el usuario, con el producto de cada una.
  Future<({List<Resena> resultados, bool haySiguiente})> getMisResenas({int page = 1}) async {
    final token = await _getToken();
    final data = await _apiClient.getMap('resenas/mias/?page=$page', token);
    final resultados = (data['results'] as List<dynamic>? ?? [])
        .map((item) => Resena.fromJson(item as Map<String, dynamic>))
        .toList();
    return (resultados: resultados, haySiguiente: data['next'] != null);
  }

  /// Ficha del producto, para abrirla desde "Mis reseñas".
  Future<Product> getProducto(int productoId) async {
    final token = await _getToken();
    final data = await _apiClient.getMap('catalogo/productos/$productoId/', token);
    return Product.fromJson(data);
  }
}