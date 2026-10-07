class PlanModel {
  final int id;
  final String codigo;
  final String nombre;
  final String precioMensual;
  final String moneda;
  final int maxUsuarios;

  PlanModel({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.precioMensual,
    required this.moneda,
    required this.maxUsuarios,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as int,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      precioMensual: json['precio_mensual'].toString(),
      moneda: json['moneda'] as String,
      maxUsuarios: json['max_usuarios'] as int,
    );
  }

  String get precioTexto => '$moneda $precioMensual / mes';
}

class SubscriptionModel {
  final int id;
  final PlanModel plan;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final String estado;
  final bool renovacionAutomatica;
  final int? diasRestantes;

  SubscriptionModel({
    required this.id,
    required this.plan,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estado,
    required this.renovacionAutomatica,
    required this.diasRestantes,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as int,
      plan: PlanModel.fromJson(json['plan'] as Map<String, dynamic>),
      fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
      fechaFin: json['fecha_fin'] == null
          ? null
          : DateTime.parse(json['fecha_fin'] as String),
      estado: json['estado'] as String,
      renovacionAutomatica: json['renovacion_automatica'] as bool,
      diasRestantes: json['dias_restantes'] as int?,
    );
  }
}

class TenantSubscriptionInfo {
  final int tenantId;
  final String tenantNombre;
  final String tenantEstado;
  final SubscriptionModel? actual;
  final List<SubscriptionModel> historial;
  final bool puedeGestionar;

  TenantSubscriptionInfo({
    required this.tenantId,
    required this.tenantNombre,
    required this.tenantEstado,
    required this.actual,
    required this.historial,
    required this.puedeGestionar,
  });

  factory TenantSubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final tenant = json['tenant'] as Map<String, dynamic>;
    return TenantSubscriptionInfo(
      tenantId: tenant['id'] as int,
      tenantNombre: tenant['nombre_comercial'] as String,
      tenantEstado: tenant['estado'] as String,
      actual: json['actual'] == null
          ? null
          : SubscriptionModel.fromJson(json['actual'] as Map<String, dynamic>),
      historial: (json['historial'] as List<dynamic>)
          .map((item) => SubscriptionModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      puedeGestionar: json['puede_gestionar'] as bool,
    );
  }
}