/// Registro de la bitácora confidencial.
///
/// La fecha y la hora llegan del servidor ya en hora de Bolivia
/// (America/La_Paz, UTC-4), así que se muestran tal cual, sin convertirlas
/// a la zona horaria del celular.
class Bitacora {
  final String id;
  final String fecha;
  final String hora;
  final String? ip;
  final int? usuarioId;
  final String? usuario;
  final String? correo;
  final String accion;
  final String? metodo;
  final String? ruta;
  final int? estado;

  const Bitacora({
    required this.id,
    required this.fecha,
    required this.hora,
    required this.ip,
    required this.usuarioId,
    required this.usuario,
    required this.correo,
    required this.accion,
    required this.metodo,
    required this.ruta,
    required this.estado,
  });

  factory Bitacora.fromJson(Map<String, dynamic> json) {
    return Bitacora(
      id: (json['id'] ?? '').toString(),
      fecha: (json['fecha'] ?? '').toString(),
      hora: (json['hora'] ?? '').toString(),
      ip: json['ip'] as String?,
      usuarioId: json['usuario_id'] as int?,
      usuario: json['usuario'] as String?,
      correo: json['correo'] as String?,
      accion: (json['accion'] ?? '').toString(),
      metodo: json['metodo'] as String?,
      ruta: json['ruta'] as String?,
      estado: json['estado'] as int?,
    );
  }

  /// Nombre a mostrar: usuario, o su correo, o "Visitante" si no inició sesión.
  String get quien {
    final nombre = (usuario ?? '').trim();
    if (nombre.isNotEmpty) return nombre;
    final mail = (correo ?? '').trim();
    return mail.isNotEmpty ? mail : 'Visitante';
  }

  bool get fueRechazada => (estado ?? 0) >= 400;
}

/// Resultado de una consulta a la bitácora.
class BitacoraResultado {
  final int total;
  final int mostrando;
  final String zonaHoraria;
  final List<Bitacora> registros;

  const BitacoraResultado({
    required this.total,
    required this.mostrando,
    required this.zonaHoraria,
    required this.registros,
  });

  factory BitacoraResultado.fromJson(Map<String, dynamic> json) {
    return BitacoraResultado(
      total: (json['total'] as int?) ?? 0,
      mostrando: (json['mostrando'] as int?) ?? 0,
      zonaHoraria: (json['zona_horaria'] as String?) ?? 'America/La_Paz (UTC-04:00)',
      registros: (json['registros'] as List<dynamic>? ?? [])
          .map((item) => Bitacora.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}