/// Datos de "Mi perfil" (GET/PUT /auth/perfil/).
class ClientProfile {
  final int id;
  final String email;
  final String nombres;
  final String apellidos;
  final String? telefono;
  final bool esCliente;
  final String? tipoDocumento;
  final String? numeroDocumento;
  final DateTime? fechaNacimiento;

  ClientProfile({
    required this.id,
    required this.email,
    required this.nombres,
    required this.apellidos,
    required this.telefono,
    required this.esCliente,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.fechaNacimiento,
  });

  factory ClientProfile.fromJson(Map<String, dynamic> json) {
    final fecha = json['fecha_nacimiento'] as String?;
    return ClientProfile(
      id: json['id'] as int,
      email: json['email'] as String,
      nombres: (json['nombres'] as String?) ?? '',
      apellidos: (json['apellidos'] as String?) ?? '',
      telefono: json['telefono'] as String?,
      esCliente: (json['es_cliente'] as bool?) ?? false,
      tipoDocumento: json['tipo_documento'] as String?,
      numeroDocumento: json['numero_documento'] as String?,
      fechaNacimiento: (fecha == null || fecha.isEmpty) ? null : DateTime.parse(fecha),
    );
  }
}