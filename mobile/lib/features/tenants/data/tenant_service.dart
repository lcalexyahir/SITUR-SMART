import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/tenant.dart';

class TenantService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  Future<String> _getToken() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      throw Exception('No existe token');
    }
    return token;
  }

  Future<List<Tenant>> getTenants() async {
    final token = await _getToken();
    final data = await _apiClient.getList('tenants/', token);
    return data.map((json) => Tenant.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Tenant> getTenant(int id) async {
    final token = await _getToken();
    final data = await _apiClient.getMap('tenants/$id/', token);
    return Tenant.fromJson(data);
  }

  Future<Map<String, dynamic>> createTenant(
    Map<String, dynamic> body,
  ) async {
    return _apiClient.postAuth('tenants/', body);
  }

  Future<Map<String, dynamic>> updateTenant(
    int id,
    Map<String, dynamic> body,
  ) async {
    return _apiClient.putAuth('tenants/$id/', body);
  }

  /// Cambia el estado operativo: ACTIVO, SUSPENDIDO o INACTIVO.
  Future<Tenant> changeStatus(int id, String estado) async {
    final data = await _apiClient.postAuth('tenants/$id/estado/', {'estado': estado});
    return Tenant.fromJson(data);
  }

  Future<void> deleteTenant(
    int id,
  ) async {
    await _apiClient.deleteAuth('tenants/$id/');
  }
}