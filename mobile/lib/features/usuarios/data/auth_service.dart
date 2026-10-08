import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      'auth/login/',
      {
        'email': email,
        'password': password,
      },
    );
    return response;
  }

  /// Registra un cliente (viajero). El servidor devuelve la sesión iniciada,
  /// que se guarda igual que en el login (tokens + usuario).
  Future<Map<String, dynamic>> registerClient({
    required String nombres,
    required String apellidos,
    required String email,
    required String password,
    String? telefono,
  }) async {
    final response = await _apiClient.post(
      'auth/register/',
      {
        'nombres': nombres,
        'apellidos': apellidos,
        'email': email,
        'password': password,
        'telefono': telefono ?? '',
      },
    );
    await _storage.saveTokens(
      access: response['access'] as String,
      refresh: response['refresh'] as String,
    );
    await _storage.saveUser(response['user'] as Map<String, dynamic>);
    return response;
  }

  /// Al abrir la app: si hay una sesión guardada, la renueva en el servidor.
  /// Devuelve true si el usuario puede entrar sin volver a iniciar sesión.
  Future<bool> restoreSession() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh == null) {
      return false;
    }
    return _apiClient.refreshSession();
  }

  /// Cierra la sesión en el servidor (si es posible) y borra los datos locales.
  Future<void> logout() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh != null) {
      try {
        await _apiClient.post('auth/logout/', {'refresh': refresh});
      } catch (_) {
        // Si el servidor no está disponible, igual se cierra en el dispositivo.
      }
    }
    await _storage.clearTokens();
  }
}