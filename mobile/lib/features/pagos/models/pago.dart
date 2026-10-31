import 'package:flutter/material.dart';

/// Pago de una reserva hecha en la web. La app solo lo muestra.
class Pago {
  final int id;
  final String reservaCodigo;
  final String reservaEstado;
  final String empresa;
  final String? producto;
  final String? productoTipo;
  final String simbolo;
  final String monto;
  final String metodo;
  final String estado;
  final String proveedor;
  final DateTime creadoEn;
  final DateTime? procesadoEn;
  final List<Reembolso> reembolsos;

  Pago({
    required this.id,
    required this.reservaCodigo,
    required this.reservaEstado,
    required this.empresa,
    required this.producto,
    required this.productoTipo,
    required this.simbolo,
    required this.monto,
    required this.metodo,
    required this.estado,
    required this.proveedor,
    required this.creadoEn,
    required this.procesadoEn,
    required this.reembolsos,
  });

  factory Pago.fromJson(Map<String, dynamic> json) {
    final reserva = (json['reserva'] as Map<String, dynamic>?) ?? {};
    final producto = json['producto'];
    return Pago(
      id: json['id'] as int,
      reservaCodigo: (reserva['codigo'] as String?) ?? '',
      reservaEstado: (reserva['estado'] as String?) ?? '',
      empresa: (json['empresa'] as String?) ?? '',
      producto: producto is Map<String, dynamic> ? producto['nombre'] as String? : null,
      productoTipo: producto is Map<String, dynamic> ? producto['tipo'] as String? : null,
      simbolo: (json['simbolo'] as String?) ?? '',
      monto: (json['monto'] ?? '0').toString(),
      metodo: (json['metodo'] as String?) ?? '',
      estado: (json['estado'] as String?) ?? '',
      proveedor: (json['proveedor'] as String?) ?? '',
      creadoEn: DateTime.parse(json['creado_en'] as String).toLocal(),
      procesadoEn: json['procesado_en'] == null ? null : DateTime.parse(json['procesado_en'] as String).toLocal(),
      reembolsos: (json['reembolsos'] as List<dynamic>? ?? [])
          .map((item) => Reembolso.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  String get montoTexto => '$simbolo $monto';

  String get estadoTexto => const {
        'APROBADO': 'Aprobado',
        'PENDIENTE': 'Pendiente',
        'RECHAZADO': 'Rechazado',
        'ANULADO': 'Anulado',
      }[estado] ??
      estado;

  String get metodoTexto => const {
        'TARJETA': 'Tarjeta',
        'QR': 'QR',
        'TRANSFERENCIA': 'Transferencia',
        'EFECTIVO': 'Efectivo',
        'OTRO': 'Otro',
      }[metodo] ??
      metodo;

  Color get color {
    switch (estado) {
      case 'APROBADO':
        return const Color(0xFF16A34A);
      case 'PENDIENTE':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFFDC2626);
    }
  }

  IconData get icono {
    switch (estado) {
      case 'APROBADO':
        return Icons.check_circle_outline;
      case 'PENDIENTE':
        return Icons.schedule;
      default:
        return Icons.cancel_outlined;
    }
  }
}

class Reembolso {
  final String estado;
  final String monto;
  final String? motivo;

  Reembolso({required this.estado, required this.monto, required this.motivo});

  factory Reembolso.fromJson(Map<String, dynamic> json) => Reembolso(
        estado: (json['estado'] as String?) ?? '',
        monto: (json['monto'] ?? '0').toString(),
        motivo: json['motivo'] as String?,
      );

  String get estadoTexto => const {
        'SOLICITADO': 'Solicitado',
        'PROCESANDO': 'En proceso',
        'COMPLETADO': 'Completado',
        'FALLIDO': 'Fallido',
        'CANCELADO': 'Cancelado',
      }[estado] ??
      estado;
}

/// Total pagado por moneda.
class ResumenPagos {
  final String simbolo;
  final String total;
  final int pagos;

  ResumenPagos({required this.simbolo, required this.total, required this.pagos});

  factory ResumenPagos.fromJson(Map<String, dynamic> json) => ResumenPagos(
        simbolo: (json['simbolo'] as String?) ?? '',
        total: (json['total'] ?? '0').toString(),
        pagos: (json['pagos'] as int?) ?? 0,
      );
}