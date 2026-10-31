/// Reseña de un producto turístico (CU35), según /catalogo/productos/<id>/resenas/.
class Resena {
  final int id;
  final int calificacion;
  final String comentario;
  final String autor;
  final bool esMia;
  final bool editada;
  final DateTime creadoEn;
  final ResenaProducto? producto;

  Resena({
    required this.id,
    required this.calificacion,
    required this.comentario,
    required this.autor,
    required this.esMia,
    required this.editada,
    required this.creadoEn,
    this.producto,
  });

  factory Resena.fromJson(Map<String, dynamic> json) {
    final producto = json['producto'];
    return Resena(
      id: json['id'] as int,
      calificacion: json['calificacion'] as int,
      comentario: (json['comentario'] as String?) ?? '',
      autor: (json['autor'] as String?) ?? 'Viajero',
      esMia: (json['es_mia'] as bool?) ?? false,
      editada: (json['editada'] as bool?) ?? false,
      creadoEn: DateTime.parse(json['creado_en'] as String).toLocal(),
      producto: producto is Map<String, dynamic> ? ResenaProducto.fromJson(producto) : null,
    );
  }

  /// Iniciales para el avatar ("Ana P." → "AP").
  String get iniciales {
    final partes = autor.replaceAll('.', '').split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }
}

/// Producto al que pertenece una reseña propia (pantalla "Mis reseñas").
class ResenaProducto {
  final int id;
  final String nombre;
  final String? imagenUrl;
  final String tipo;
  final bool disponible;

  ResenaProducto({
    required this.id,
    required this.nombre,
    required this.imagenUrl,
    required this.tipo,
    required this.disponible,
  });

  factory ResenaProducto.fromJson(Map<String, dynamic> json) {
    return ResenaProducto(
      id: json['id'] as int,
      nombre: (json['nombre'] as String?) ?? '',
      imagenUrl: json['imagen_url'] as String?,
      tipo: (json['tipo'] as String?) ?? '',
      disponible: (json['disponible'] as bool?) ?? true,
    );
  }

  bool get tieneImagen => (imagenUrl ?? '').startsWith('http');
}

/// Promedio, total y cantidad de reseñas por estrella.
class ResumenResenas {
  final double? promedio;
  final int total;
  final Map<int, int> distribucion;

  ResumenResenas({
    required this.promedio,
    required this.total,
    required this.distribucion,
  });

  factory ResumenResenas.fromJson(Map<String, dynamic> json) {
    final raw = (json['distribucion'] as Map<String, dynamic>?) ?? {};
    return ResumenResenas(
      promedio: (json['promedio'] as num?)?.toDouble(),
      total: (json['total'] as int?) ?? 0,
      distribucion: {
        for (var estrellas = 1; estrellas <= 5; estrellas++)
          estrellas: (raw['$estrellas'] as int?) ?? 0,
      },
    );
  }

  String get promedioTexto => promedio == null ? '–' : promedio!.toStringAsFixed(1);

  /// Fracción (0 a 1) de reseñas con esa cantidad de estrellas.
  double porcentaje(int estrellas) => total == 0 ? 0 : (distribucion[estrellas] ?? 0) / total;
}

/// Una página de reseñas de un producto con su resumen.
class PaginaResenas {
  final ResumenResenas resumen;
  final Resena? miResena;
  final bool puedeResenar;
  final int total;
  final bool haySiguiente;
  final List<Resena> resultados;

  PaginaResenas({
    required this.resumen,
    required this.miResena,
    required this.puedeResenar,
    required this.total,
    required this.haySiguiente,
    required this.resultados,
  });

  factory PaginaResenas.fromJson(Map<String, dynamic> json) {
    final mia = json['mi_resena'];
    return PaginaResenas(
      resumen: ResumenResenas.fromJson(json['resumen'] as Map<String, dynamic>),
      miResena: mia is Map<String, dynamic> ? Resena.fromJson(mia) : null,
      puedeResenar: (json['puede_resenar'] as bool?) ?? false,
      total: (json['count'] as int?) ?? 0,
      haySiguiente: json['next'] != null,
      resultados: (json['results'] as List<dynamic>? ?? [])
          .map((item) => Resena.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Textos de cada calificación, iguales en el formulario y en la ficha.
const Map<int, String> etiquetasCalificacion = {
  1: 'Muy malo',
  2: 'Malo',
  3: 'Regular',
  4: 'Bueno',
  5: 'Excelente',
};