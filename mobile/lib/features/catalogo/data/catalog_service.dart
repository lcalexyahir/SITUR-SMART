import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/product.dart';

class CatalogService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  Future<String> _getToken() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      throw Exception('No existe token');
    }
    return token;
  }

  Future<List<ProductType>> getTypes() async {
    final token = await _getToken();
    final data = await _apiClient.getList('catalogo/tipos/', token);
    return data.map((json) => ProductType.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<Product>> getProducts({String? query, int? typeId}) async {
    final token = await _getToken();
    final params = <String, String>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (typeId != null) 'tipo': '$typeId',
    };
    final endpoint = params.isEmpty
        ? 'catalogo/productos/'
        : 'catalogo/productos/?${Uri(queryParameters: params).query}';
    final data = await _apiClient.getList(endpoint, token);
    return data.map((json) => Product.fromJson(json as Map<String, dynamic>)).toList();
  }
}