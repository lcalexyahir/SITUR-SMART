class TenantOwner {
  final int id;
  final String nombre;
  final String email;

  TenantOwner({
    required this.id,
    required this.nombre,
    required this.email,
  });

  factory TenantOwner.fromJson(Map<String, dynamic> json) {
    return TenantOwner(
      id: json['id'] as int,
      nombre: (json['nombre'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
    );
  }
}

class Tenant {
  final int id;
  final String nombreComercial;
  final String razonSocial;
  final String estado;
  final String subdomain;
  final String? nit;
  final String? emailContacto;
  final String? telefono;
  final String? ciudad;
  final DateTime? creadoEn;
  final String? suscripcionEstado;
  final String? suscripcionPlan;
  final DateTime? suscripcionFin;
  final TenantOwner? propietario;
  final bool puedeGestionar;

  Tenant({
    required this.id,
    required this.nombreComercial,
    required this.razonSocial,
    required this.estado,
    this.subdomain = '',
    this.nit,
    this.emailContacto,
    this.telefono,
    this.ciudad,
    this.creadoEn,
    this.suscripcionEstado,
    this.suscripcionPlan,
    this.suscripcionFin,
    this.propietario,
    this.puedeGestionar = false,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) {
    final suscripcion = json['suscripcion'] as Map<String, dynamic>?;
    final propietario = json['propietario'] as Map<String, dynamic>?;

    return Tenant(
      id: json['id'] as int,
      nombreComercial: json['nombre_comercial'] as String,
      razonSocial: json['razon_social'] as String,
      estado: json['estado'] as String,
      subdomain: (json['subdomain'] as String?) ?? '',
      nit: json['nit'] as String?,
      emailContacto: json['email_contacto'] as String?,
      telefono: json['telefono'] as String?,
      ciudad: json['ciudad'] as String?,
      creadoEn: json['creado_en'] == null ? null : DateTime.parse(json['creado_en'] as String).toLocal(),
      suscripcionEstado: suscripcion?['estado'] as String?,
      suscripcionPlan: suscripcion?['plan'] as String?,
      suscripcionFin: suscripcion?['fecha_fin'] == null
          ? null
          : DateTime.parse(suscripcion!['fecha_fin'] as String),
      propietario: propietario == null ? null : TenantOwner.fromJson(propietario),
      puedeGestionar: (json['puede_gestionar'] as bool?) ?? false,
    );
  }

  /// Iniciales para el avatar ("Bodegas Kohlberg" -> "BK").
  String get iniciales {
    final words = nombreComercial.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}