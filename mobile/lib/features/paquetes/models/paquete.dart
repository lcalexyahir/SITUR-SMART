import '../../itinerarios/models/itinerario.dart';

/// Paquete personalizado (CU39) que arma el turista.
class Paquete {
  final int id;
  final String nombre;
  final int? ciudadId;
  final String? ciudad;
  final DateTime inicio;
  final DateTime fin;
  final int personas;
  final String estado;
  final String total;
  final int cantidadServicios;
  final CompraPaquete? compra;
  final bool editable;
  final List<ComponentePaquete> componentes;
  final List<String> advertencias;
  final bool requiereRevalidacion;

  Paquete({
    required this.id,
    required this.nombre,
    required this.ciudadId,
    required this.ciudad,
    required this.inicio,
    required this.fin,
    required this.personas,
    required this.estado,
    required this.total,
    required this.cantidadServicios,
    required this.compra,
    required this.editable,
    required this.componentes,
    required this.advertencias,
    required this.requiereRevalidacion,
  });

  factory Paquete.fromJson(Map<String, dynamic> json) {
    final compra = json['compra'];
    return Paquete(
      id: json['id'] as int,
      nombre: (json['nombre'] as String?) ?? '',
      ciudadId: json['ciudad_id'] as int?,
      ciudad: json['ciudad'] as String?,
      inicio: Fechas.parse(json['fecha_inicio'] as String),
      fin: Fechas.parse(json['fecha_fin'] as String),
      personas: (json['personas'] as int?) ?? 1,
      estado: (json['estado'] as String?) ?? 'BORRADOR',
      total: (json['total'] ?? '0').toString(),
      cantidadServicios: (json['cantidad_servicios'] as int?) ?? 0,
      compra: compra is Map<String, dynamic> ? CompraPaquete.fromJson(compra) : null,
      editable: (json['editable'] as bool?) ?? true,
      componentes: (json['componentes'] as List<dynamic>? ?? [])
          .map((item) => ComponentePaquete.fromJson(item as Map<String, dynamic>))
          .toList(),
      advertencias: (json['advertencias'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      requiereRevalidacion: (json['requiere_revalidacion'] as bool?) ?? false,
    );
  }

  String get totalTexto => 'Bs $total';

  /// Etiqueta del estado para mostrar en la lista.
  String get estadoTexto {
    if (compra != null) return compra!.estadoTexto;
    return estado == 'GUARDADO' ? 'Cotizado' : 'Borrador';
  }

  List<DateTime> get fechas => List.generate(
        fin.difference(inicio).inDays + 1,
        (offset) => DateTime(inicio.year, inicio.month, inicio.day + offset),
      );
}

class CompraPaquete {
  final int id;
  final String estado;
  final String total;

  CompraPaquete({required this.id, required this.estado, required this.total});

  factory CompraPaquete.fromJson(Map<String, dynamic> json) => CompraPaquete(
        id: json['id'] as int,
        estado: (json['estado'] as String?) ?? '',
        total: (json['total'] ?? '0').toString(),
      );

  String get estadoTexto => const {
        'CREADA': 'Compra pendiente de pago',
        'CONFIRMADA': 'Comprado',
        'CANCELADA': 'Compra cancelada',
        'EXPIRADA': 'Compra expirada',
        'REEMBOLSADA': 'Compra reembolsada',
      }[estado] ??
      estado;
}

class ComponentePaquete {
  final int id;
  final int productoId;
  final String nombre;
  final String tipo;
  final String tipoCodigo;
  final String empresa;
  final String ciudad;
  final String? imagenUrl;
  final DateTime inicio;
  final DateTime? fin;
  final int cantidad;
  final int? huespedes;
  final String? horaInicio;
  final String precioUnitario;
  final String total;
  final bool disponible;
  final bool requiereRevalidacion;
  final String? motivo;

  ComponentePaquete({
    required this.id,
    required this.productoId,
    required this.nombre,
    required this.tipo,
    required this.tipoCodigo,
    required this.empresa,
    required this.ciudad,
    required this.imagenUrl,
    required this.inicio,
    required this.fin,
    required this.cantidad,
    required this.huespedes,
    required this.horaInicio,
    required this.precioUnitario,
    required this.total,
    required this.disponible,
    required this.requiereRevalidacion,
    required this.motivo,
  });

  factory ComponentePaquete.fromJson(Map<String, dynamic> json) => ComponentePaquete(
        id: json['id'] as int,
        productoId: json['producto_id'] as int,
        nombre: (json['nombre'] as String?) ?? '',
        tipo: (json['tipo'] as String?) ?? '',
        tipoCodigo: (json['tipo_codigo'] as String?) ?? '',
        empresa: (json['empresa'] as String?) ?? '',
        ciudad: (json['ciudad'] as String?) ?? '',
        imagenUrl: json['imagen_url'] as String?,
        inicio: Fechas.parse(json['fecha_inicio'] as String),
        fin: json['fecha_fin'] == null ? null : Fechas.parse(json['fecha_fin'] as String),
        cantidad: (json['cantidad'] as int?) ?? 1,
        huespedes: json['huespedes'] as int?,
        horaInicio: json['hora_inicio'] as String?,
        precioUnitario: (json['precio_unitario'] ?? '0').toString(),
        total: (json['total'] ?? '0').toString(),
        disponible: (json['disponible'] as bool?) ?? true,
        requiereRevalidacion: (json['requiere_revalidacion'] as bool?) ?? false,
        motivo: json['motivo'] as String?,
      );

  bool get esHospedaje => tipoCodigo == 'HABITACION';

  /// "2 habitaciones · 3 noches · 4 huéspedes" o "3 personas · 09:00".
  String get detalle {
    if (esHospedaje) {
      final noches = fin == null ? 0 : fin!.difference(inicio).inDays;
      return [
        cantidad == 1 ? '1 habitación' : '$cantidad habitaciones',
        noches == 1 ? '1 noche' : '$noches noches',
        if (huespedes != null) (huespedes == 1 ? '1 huésped' : '$huespedes huéspedes'),
      ].join(' · ');
    }
    return [
      cantidad == 1 ? '1 persona' : '$cantidad personas',
      if (horaInicio != null) 'salida $horaInicio',
    ].join(' · ');
  }

  String get fechasTexto => esHospedaje && fin != null
      ? '${Fechas.conDia(inicio)} → ${Fechas.conDia(fin!)}'
      : Fechas.conDia(inicio);
}

/// Tipos de servicio que se pueden sumar a un paquete.
const Map<String, String> tiposServicio = {
  'HABITACION': 'Hospedaje',
  'TOUR': 'Tour',
  'EXPERIENCIA': 'Experiencia',
  'ATRACCION': 'Atracción',
  'RESTAURANTE': 'Restaurante',
};