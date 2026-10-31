import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/pago.dart';

/// Historial de pagos del turista (solo consulta, sin pasarela).
class PagoService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  Future<String> _getToken() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      throw Exception('No existe token');
    }
    return token;
  }

  Future<({List<Pago> pagos, List<ResumenPagos> resumen, bool haySiguiente})> getPagos({
    String? estado,
    int page = 1,
  }) async {
    final token = await _getToken();
    final params = <String, String>{'page': '$page', if (estado != null) 'estado': estado};
    final data = await _apiClient.getMap('pagos/?${Uri(queryParameters: params).query}', token);
    return (
      pagos: (data['results'] as List<dynamic>? ?? [])
          .map((item) => Pago.fromJson(item as Map<String, dynamic>))
          .toList(),
      resumen: (data['resumen'] as List<dynamic>? ?? [])
          .map((item) => ResumenPagos.fromJson(item as Map<String, dynamic>))
          .toList(),
      haySiguiente: data['next'] != null,
    );
  }
}