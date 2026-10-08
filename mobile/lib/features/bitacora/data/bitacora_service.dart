import '../../../core/network/api_client.dart';
import '../models/bitacora.dart';

/// Consulta la bitácora confidencial del servidor.
///
/// Endpoint: POST /api/v1/audit/log-seguro/
/// Requiere la llave única del desarrollador. La llave no se guarda en el
/// celular: solo vive en memoria mientras la pantalla está abierta.
class BitacoraService {
  final ApiClient _apiClient = ApiClient();

  Future<BitacoraResultado> consultar({
    required String llave,
    DateTime? desde,
    DateTime? hasta,
    String usuario = '',
    String accion = '',
    String ip = '',
  }) async {
    final data = await _apiClient.postAuth(
      'audit/log-seguro/',
      {
        'llave': llave,
        'desde': desde == null ? null : _fecha(desde),
        'hasta': hasta == null ? null : _fecha(hasta),
        'usuario': usuario.trim(),
        'accion': accion.trim(),
        'ip': ip.trim(),
      },
    );
    return BitacoraResultado.fromJson(data);
  }

  String _fecha(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}