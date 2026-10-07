import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/current_user.dart';

class CurrentUserService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  Future<CurrentUser> getCurrentUser() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      throw Exception('No existe token');
    }
    final data = await _apiClient.getMap('auth/me/', token);
    return CurrentUser.fromJson(data);
  }
}