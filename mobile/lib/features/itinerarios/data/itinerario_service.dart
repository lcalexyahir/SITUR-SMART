import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/itinerario.dart';

/// Itinerarios del turista. Usan las mismas tablas que la web.
class ItinerarioService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  static List<Ciudad>? _ciudades;

  Future<String> _getToken() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      throw Exception('No existe token');
    }
    return token;
  }

  Future<List<Itinerario>> getItinerarios() async {
    final token = await _getToken();
    final data = await _apiClient.getList('itinerarios/', token);
    return data.map((json) => Itinerario.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Itinerario> getItinerario(int id) async {
    final token = await _getToken();
    return Itinerario.fromJson(await _apiClient.getMap('itinerarios/$id/', token));
  }

  Map<String, dynamic> _cuerpo({
    required String nombre,
    required DateTime inicio,
    required DateTime fin,
    int? ciudadId,
    String? notas,
  }) =>
      {
        'nombre': nombre.trim(),
        'inicio': Fechas.api(inicio),
        'fin': Fechas.api(fin),
        'ciudad_id': ciudadId,
        'notas': (notas ?? '').trim().isEmpty ? null : notas!.trim(),
      };

  Future<Itinerario> crear({
    required String nombre,
    required DateTime inicio,
    required DateTime fin,
    int? ciudadId,
    String? notas,
  }) async {
    final data = await _apiClient.postAuth(
      'itinerarios/',
      _cuerpo(nombre: nombre, inicio: inicio, fin: fin, ciudadId: ciudadId, notas: notas),
    );
    return Itinerario.fromJson(data);
  }

  Future<Itinerario> editar(
    int id, {
    required String nombre,
    required DateTime inicio,
    required DateTime fin,
    int? ciudadId,
    String? notas,
  }) async {
    final data = await _apiClient.putAuth(
      'itinerarios/$id/',
      _cuerpo(nombre: nombre, inicio: inicio, fin: fin, ciudadId: ciudadId, notas: notas),
    );
    return Itinerario.fromJson(data);
  }

  Future<void> eliminar(int id) => _apiClient.deleteAuth('itinerarios/$id/');

  Future<void> agregarActividad(
    int itinerarioId, {
    required DateTime fecha,
    String? hora,
    String? titulo,
    String? nota,
    int? productoId,
  }) async {
    await _apiClient.postAuth('itinerarios/$itinerarioId/actividades/', {
      'fecha': Fechas.api(fecha),
      'hora': hora,
      'titulo': (titulo ?? '').trim().isEmpty ? null : titulo!.trim(),
      'nota': (nota ?? '').trim().isEmpty ? null : nota!.trim(),
      'producto_id': productoId,
    });
  }

  Future<void> editarActividad(
    int itinerarioId,
    int actividadId, {
    required DateTime fecha,
    String? hora,
    required String titulo,
    String? nota,
  }) async {
    await _apiClient.putAuth('itinerarios/$itinerarioId/actividades/$actividadId/', {
      'fecha': Fechas.api(fecha),
      'hora': hora,
      'titulo': titulo.trim(),
      'nota': (nota ?? '').trim().isEmpty ? null : nota!.trim(),
    });
  }

  Future<void> eliminarActividad(int itinerarioId, int actividadId) =>
      _apiClient.deleteAuth('itinerarios/$itinerarioId/actividades/$actividadId/');

  /// Ciudades para los formularios. Se piden una sola vez.
  Future<List<Ciudad>> getCiudades() async {
    if (_ciudades != null) return _ciudades!;
    final token = await _getToken();
    final data = await _apiClient.getList('itinerarios/ciudades/', token);
    _ciudades = data.map((json) => Ciudad.fromJson(json as Map<String, dynamic>)).toList();
    return _ciudades!;
  }
}