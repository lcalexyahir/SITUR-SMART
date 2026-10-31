import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Aviso de la bandeja del usuario (CU45), según /notificaciones/.
class Notificacion {
  final int id;
  final String tipo;
  final String titulo;
  final String mensaje;
  final Map<String, dynamic> datos;
  final bool leida;
  final bool esRecordatorio;
  final DateTime creadoEn;

  Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.datos,
    required this.leida,
    required this.esRecordatorio,
    required this.creadoEn,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    final tipo = (json['tipo'] as String?) ?? '';
    return Notificacion(
      id: json['id'] as int,
      tipo: tipo,
      titulo: (json['titulo'] as String?) ?? '',
      mensaje: (json['mensaje'] as String?) ?? '',
      datos: (json['datos'] as Map<String, dynamic>?) ?? const {},
      leida: (json['leida'] as bool?) ?? false,
      esRecordatorio: (json['es_recordatorio'] as bool?) ?? tipo.startsWith('RECORDATORIO'),
      creadoEn: DateTime.parse(json['creado_en'] as String).toLocal(),
    );
  }

  Notificacion copiaLeida() => Notificacion(
        id: id,
        tipo: tipo,
        titulo: titulo,
        mensaje: mensaje,
        datos: datos,
        leida: true,
        esRecordatorio: esRecordatorio,
        creadoEn: creadoEn,
      );

  /// Código de la reserva relacionada, si el aviso trae uno.
  String? get codigoReserva => datos['codigo'] as String?;

  /// Inicio de la reserva (lo traen los recordatorios).
  DateTime? get inicio {
    final valor = datos['inicio'];
    if (valor is! String) return null;
    return DateTime.tryParse(valor)?.toLocal();
  }

  String get etiquetaTipo => _estilos[tipo]?.etiqueta ?? (esRecordatorio ? 'Recordatorio' : 'Aviso');

  IconData get icono => _estilos[tipo]?.icono ?? (esRecordatorio ? Icons.alarm : Icons.notifications_none);

  Color get color => _estilos[tipo]?.color ?? (esRecordatorio ? const Color(0xFF7C3AED) : const Color(0xFF0F766E));

  /// "Hace 5 min", "Ayer", "12/10/2026".
  String get tiempoRelativo {
    final diferencia = DateTime.now().difference(creadoEn);
    if (diferencia.inMinutes < 1) return 'Ahora';
    if (diferencia.inMinutes < 60) return 'Hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'Hace ${diferencia.inHours} h';
    if (diferencia.inDays == 1) return 'Ayer';
    if (diferencia.inDays < 7) return 'Hace ${diferencia.inDays} días';
    return DateFormat('dd/MM/yyyy').format(creadoEn);
  }
}

class _EstiloAviso {
  const _EstiloAviso(this.etiqueta, this.icono, this.color);

  final String etiqueta;
  final IconData icono;
  final Color color;
}

/// Tipos que generan la web y su backend en la tabla compartida.
const Map<String, _EstiloAviso> _estilos = {
  'RESERVA_CONFIRMADA': _EstiloAviso('Reserva confirmada', Icons.check_circle_outline, Color(0xFF16A34A)),
  'RESERVA_VENCIDA': _EstiloAviso('Reserva vencida', Icons.timer_off_outlined, Color(0xFFD97706)),
  'RESERVA_CANCELADA': _EstiloAviso('Reserva cancelada', Icons.cancel_outlined, Color(0xFFDC2626)),
  'PAGO_REVISION': _EstiloAviso('Pago en revisión', Icons.payments_outlined, Color(0xFFD97706)),
  'REEMBOLSO_COMPLETADO': _EstiloAviso('Reembolso completado', Icons.currency_exchange, Color(0xFF16A34A)),
  'REEMBOLSO_FALLIDO': _EstiloAviso('Reembolso fallido', Icons.currency_exchange, Color(0xFFDC2626)),
  'RECORDATORIO_24H': _EstiloAviso('Recordatorio · mañana', Icons.alarm, Color(0xFF7C3AED)),
  'RECORDATORIO_2H': _EstiloAviso('Recordatorio · en 2 horas', Icons.alarm_on, Color(0xFF7C3AED)),
};