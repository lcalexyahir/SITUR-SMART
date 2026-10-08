/// Usuario que inició sesión, según /auth/me/.
class CurrentUser {
  final int id;
  final String email;
  final String nombres;
  final String apellidos;
  final List<String> roles;
  final List<String> permisos;
  final bool esCliente;

  CurrentUser({
    required this.id,
    required this.email,
    required this.nombres,
    required this.apellidos,
    required this.roles,
    required this.permisos,
    required this.esCliente,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as int,
      email: json['email'] as String,
      nombres: (json['nombres'] as String?) ?? '',
      apellidos: (json['apellidos'] as String?) ?? '',
      roles: (json['roles'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      permisos: (json['permisos'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      esCliente: (json['es_cliente'] as bool?) ?? false,
    );
  }

  bool get isSuperAdmin => roles.contains('SUPER_ADMIN');

  /// Un cliente (viajero) es quien tiene perfil de cliente y no es personal
  /// de una empresa ni SuperAdmin.
  bool get isClient => esCliente && !isSuperAdmin;

  /// Nombre para el saludo.
  String get saludo => nombres.trim().isEmpty ? email : nombres.trim();

  String get nombreCompleto {
    final full = '${nombres.trim()} ${apellidos.trim()}'.trim();
    return full.isEmpty ? email : full;
  }

  String get iniciales {
    final parts = nombreCompleto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String get rolPrincipal {
    if (isSuperAdmin) return 'SUPERADMIN';
    if (isClient) return 'Viajero / Turista';
    return roles.isEmpty ? 'USUARIO' : roles.first;
  }
}