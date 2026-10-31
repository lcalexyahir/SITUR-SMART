import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../catalogo/models/product.dart';
import '../../itinerarios/models/itinerario.dart';
import '../models/paquete.dart';

/// CU39: el turista arma y cotiza paquetes. La compra se hace en la web.
class PaqueteService {
  final ApiClient _apiClient = ApiClient();
  final TokenStorage _storage = TokenStorage();

  Future<String> _getToken() async {
    final token = await _storage.getAccessToken();
    if (token == null) {
      throw Exception('No existe token');
    }
    return token;
  }

  Future<List<Paquete>> getPaquetes() async {
    final token = await _getToken();
    final data = await _apiClient.getList('paquetes/', token);
    return data.map((json) => Paquete.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Paquete> getPaquete(int id) async {
    final token = await _getToken();
    return Paquete.fromJson(await _apiClient.getMap('paquetes/$id/', token));
  }

  Map<String, dynamic> _cuerpo(String nombre, DateTime inicio, DateTime fin, int personas, int? ciudadId) => {
        'nombre': nombre.trim(),
        'fecha_inicio': Fechas.api(inicio),
        'fecha_fin': Fechas.api(fin),
        'personas': personas,
        'ciudad_id': ciudadId,
      };

  Future<Paquete> crear({
    required String nombre,
    required DateTime inicio,
    required DateTime fin,
    required int personas,
    int? ciudadId,
  }) async {
    final data = await _apiClient.postAuth('paquetes/', _cuerpo(nombre, inicio, fin, personas, ciudadId));
    return Paquete.fromJson(data);
  }

  Future<Paquete> editar(
    int id, {
    required String nombre,
    required DateTime inicio,
    required DateTime fin,
    required int personas,
    int? ciudadId,
  }) async {
    final data = await _apiClient.putAuth('paquetes/$id/', _cuerpo(nombre, inicio, fin, personas, ciudadId));
    return Paquete.fromJson(data);
  }

  Future<void> eliminar(int id) => _apiClient.deleteAuth('paquetes/$id/');

  /// Servicios que se pueden sumar (en bolivianos y con precio).
  Future<List<Product>> getCatalogo({String? texto, String? tipo, int? ciudadId}) async {
    final token = await _getToken();
    final params = <String, String>{
      if (texto != null && texto.trim().isNotEmpty) 'q': texto.trim(),
      if (tipo != null) 'tipo': tipo,
      if (ciudadId != null) 'ciudad_id': '$ciudadId',
    };
    final endpoint = params.isEmpty ? 'paquetes/catalogo/' : 'paquetes/catalogo/?${Uri(queryParameters: params).query}';
    final data = await _apiClient.getList(endpoint, token);
    return data.map((json) => Product.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Paquete> agregarServicio(
    int paqueteId, {
    required int productoId,
    required DateTime inicio,
    DateTime? fin,
    required int cantidad,
    int? huespedes,
  }) async {
    final data = await _apiClient.postAuth('paquetes/$paqueteId/componentes/', {
      'producto_id': productoId,
      'fecha_inicio': Fechas.api(inicio),
      'fecha_fin': fin == null ? null : Fechas.api(fin),
      'cantidad': cantidad,
      'huespedes': huespedes,
    });
    return Paquete.fromJson(data);
  }

  Future<void> quitarServicio(int paqueteId, int componenteId) =>
      _apiClient.deleteAuth('paquetes/$paqueteId/componentes/$componenteId/');

  /// Vuelve a cotizar todo; con [guardar] queda como paquete cotizado (GUARDADO).
  Future<Paquete> cotizar(int paqueteId, {required bool guardar}) async {
    final data = await _apiClient.postAuth('paquetes/$paqueteId/cotizar/', {'guardar': guardar});
    return Paquete.fromJson(data);
  }
}