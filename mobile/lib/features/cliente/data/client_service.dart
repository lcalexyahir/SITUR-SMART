import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/client_profile.dart';

class ClientService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  Future<ClientProfile> getProfile() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      throw Exception('No existe token');
    }
    final data = await _apiClient.getMap('auth/perfil/', token);
    return ClientProfile.fromJson(data);
  }

  Future<ClientProfile> updateProfile({
    required String nombres,
    required String apellidos,
    String? telefono,
    String? tipoDocumento,
    String? numeroDocumento,
    DateTime? fechaNacimiento,
  }) async {
    final data = await _apiClient.putAuth(
      'auth/perfil/',
      {
        'nombres': nombres,
        'apellidos': apellidos,
        'telefono': telefono ?? '',
        'tipo_documento': tipoDocumento ?? '',
        'numero_documento': numeroDocumento ?? '',
        'fecha_nacimiento': fechaNacimiento == null
            ? null
            : '${fechaNacimiento.year.toString().padLeft(4, '0')}-'
                '${fechaNacimiento.month.toString().padLeft(2, '0')}-'
                '${fechaNacimiento.day.toString().padLeft(2, '0')}',
      },
    );
    return ClientProfile.fromJson(data);
  }

  Future<void> changePassword({
    required String actual,
    required String nueva,
  }) async {
    await _apiClient.postAuth(
      'auth/cambiar-password/',
      {
        'actual': actual,
        'nueva': nueva,
      },
    );
  }
}