import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/subscription.dart';

class SubscriptionService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  Future<String> _getToken() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      throw Exception('No existe token');
    }
    return token;
  }

  Future<TenantSubscriptionInfo> getTenantSubscription(int tenantId) async {
    final token = await _getToken();
    final data = await _apiClient.getMap(
      'tenants/$tenantId/suscripcion/',
      token,
    );
    return TenantSubscriptionInfo.fromJson(data);
  }

  Future<List<PlanModel>> getPlans() async {
    final token = await _getToken();
    final data = await _apiClient.getList('planes/', token);
    return data
        .map((json) => PlanModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> assign({
    required int tenantId,
    required int planId,
    required int meses,
    required bool renovacionAutomatica,
  }) async {
    await _apiClient.postAuth(
      'tenants/$tenantId/suscripcion/asignar/',
      {
        'plan_id': planId,
        'meses': meses,
        'renovacion_automatica': renovacionAutomatica,
      },
    );
  }

  Future<void> renew({
    required int tenantId,
    required int meses,
  }) async {
    await _apiClient.postAuth(
      'tenants/$tenantId/suscripcion/renovar/',
      {'meses': meses},
    );
  }

  Future<void> suspend({
    required int tenantId,
  }) async {
    await _apiClient.postAuth(
      'tenants/$tenantId/suscripcion/suspender/',
      {},
    );
  }

  /// Convierte el error del servidor en un mensaje legible.
  static String errorMessage(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is Map<String, dynamic>) {
          final details = err['details'];
          if (details is Map<String, dynamic>) {
            for (final value in details.values) {
              if (value is List && value.isNotEmpty) {
                return value.first.toString();
              }
              if (value is String) {
                return value;
              }
            }
          }
          if (err['message'] is String) {
            return err['message'] as String;
          }
        }
      }
    } catch (_) {
      // No es JSON: se devuelve el texto original.
    }
    return raw;
  }
}