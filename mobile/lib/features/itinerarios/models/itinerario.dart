import 'package:intl/intl.dart';

/// Ciudad para los formularios de itinerario y paquete.
class Ciudad {
  final int id;
  final String nombre;
  final String pais;

  Ciudad({required this.id, required this.nombre, required this.pais});

  factory Ciudad.fromJson(Map<String, dynamic> json) => Ciudad(
        id: json['id'] as int,
        nombre: (json['nombre'] as String?) ?? '',
        pais: (json['pais'] as String?) ?? '',
      );

  String get etiqueta => pais.isEmpty ? nombre : '$nombre, $pais';
}

/// Fechas en el formato que espera el servidor (yyyy-MM-dd) y en texto para la app.
class Fechas {
  Fechas._();

  static final DateFormat _api = DateFormat('yyyy-MM-dd');
  static final DateFormat _corta = DateFormat('dd/MM/yyyy');
  static const List<String> _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const List<String> _diasLargos = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  static String api(DateTime fecha) => _api.format(fecha);

  static DateTime parse(String valor) => DateTime.parse(valor);

  static String corta(DateTime fecha) => _corta.format(fecha);

  /// "Lun 03/11/2026"
  static String conDia(DateTime fecha) => '${_dias[fecha.weekday - 1]} ${_corta.format(fecha)}';

  /// "Lunes"
  static String dia(DateTime fecha) => _diasLargos[fecha.weekday - 1];

  static String rango(DateTime inicio, DateTime fin) =>
      inicio == fin ? corta(inicio) : '${corta(inicio)} – ${corta(fin)}';

  static DateTime soloFecha(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);
}

/// Itinerario en la lista.
class Itinerario {
  final int id;
  final String nombre;
  final int? ciudadId;
  final String? ciudad;
  final DateTime inicio;
  final DateTime fin;
  final String? notas;
  final int dias;
  final int actividades;
  final List<DiaItinerario> diasDetalle;

  Itinerario({
    required this.id,
    required this.nombre,
    required this.ciudadId,
    required this.ciudad,
    required this.inicio,
    required this.fin,
    required this.notas,
    required this.dias,
    required this.actividades,
    required this.diasDetalle,
  });

  factory Itinerario.fromJson(Map<String, dynamic> json) {
    final ciudad = json['ciudad'];
    return Itinerario(
      id: json['id'] as int,
      nombre: (json['nombre'] as String?) ?? '',
      ciudadId: ciudad is Map<String, dynamic> ? ciudad['id'] as int? : null,
      ciudad: ciudad is Map<String, dynamic> ? ciudad['nombre'] as String? : null,
      inicio: Fechas.parse(json['inicio'] as String),
      fin: Fechas.parse(json['fin'] as String),
      notas: json['notas'] as String?,
      dias: (json['dias'] as int?) ?? 1,
      actividades: (json['actividades'] as int?) ?? 0,
      diasDetalle: (json['dias_detalle'] as List<dynamic>? ?? [])
          .map((item) => DiaItinerario.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Días del viaje, para elegir el día de una actividad.
  List<DateTime> get fechas => List.generate(
        fin.difference(inicio).inDays + 1,
        (offset) => DateTime(inicio.year, inicio.month, inicio.day + offset),
      );

  /// "En curso", "Faltan 5 días", "Terminado".
  String get estadoTexto {
    final hoy = Fechas.soloFecha(DateTime.now());
    if (hoy.isBefore(inicio)) {
      final faltan = inicio.difference(hoy).inDays;
      return faltan == 1 ? 'Empieza mañana' : 'Faltan $faltan días';
    }
    if (hoy.isAfter(fin)) return 'Terminado';
    return 'En curso';
  }
}

class DiaItinerario {
  final DateTime fecha;
  final List<Actividad> actividades;

  DiaItinerario({required this.fecha, required this.actividades});

  factory DiaItinerario.fromJson(Map<String, dynamic> json) => DiaItinerario(
        fecha: Fechas.parse(json['fecha'] as String),
        actividades: (json['actividades'] as List<dynamic>? ?? [])
            .map((item) => Actividad.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class Actividad {
  final int id;
  final DateTime fecha;
  final String? hora;
  final String titulo;
  final String? nota;
  final ActividadProducto? producto;

  Actividad({
    required this.id,
    required this.fecha,
    required this.hora,
    required this.titulo,
    required this.nota,
    required this.producto,
  });

  factory Actividad.fromJson(Map<String, dynamic> json) {
    final producto = json['producto'];
    return Actividad(
      id: json['id'] as int,
      fecha: Fechas.parse(json['fecha'] as String),
      hora: json['hora'] as String?,
      titulo: (json['titulo'] as String?) ?? '',
      nota: json['nota'] as String?,
      producto: producto is Map<String, dynamic> ? ActividadProducto.fromJson(producto) : null,
    );
  }
}

class ActividadProducto {
  final int id;
  final String nombre;
  final String? imagenUrl;
  final String tipo;

  ActividadProducto({required this.id, required this.nombre, required this.imagenUrl, required this.tipo});

  factory ActividadProducto.fromJson(Map<String, dynamic> json) => ActividadProducto(
        id: json['id'] as int,
        nombre: (json['nombre'] as String?) ?? '',
        imagenUrl: json['imagen_url'] as String?,
        tipo: (json['tipo'] as String?) ?? '',
      );
}