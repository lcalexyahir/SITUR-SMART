/// Usuario que inició sesión, según /auth/me/.
class CurrentUser {
  final int id;
  final String email;
  final String nombres;
  final String apellidos;
  final List<String> roles;
  final List<String> permisos;

  CurrentUser({
    required this.id,
    required this.email,
    required this.nombres,
    required this.apellidos,
    required this.roles,
    required this.permisos,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as int,
      email: json['email'] as String,
      nombres: (json['nombres'] as String?) ?? '',
      apellidos: (json['apellidos'] as String?) ?? '',
      roles: (json['roles'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      permisos: (json['permisos'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }

  bool get isSuperAdmin => roles.contains('SUPER_ADMIN');

  /// Primer nombre para el saludo ("Jose Carlos" -> "Jose Carlos").
  String get saludo => nombres.trim().isEmpty ? email : nombres.trim();

  String get rolPrincipal {
    if (isSuperAdmin) return 'SUPERADMIN';
    return roles.isEmpty ? 'USUARIO' : roles.first;
  }
}