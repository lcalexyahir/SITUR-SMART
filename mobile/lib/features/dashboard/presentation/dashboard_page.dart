import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../tenants/data/tenant_service.dart';
import '../../tenants/models/tenant.dart';
import '../../tenants/presentation/tenant_detail_page.dart';
import '../../tenants/presentation/tenant_form_page.dart';
import '../../tenants/presentation/tenant_ui.dart';
import '../../tenants/presentation/tenants_list_page.dart';
import '../data/current_user_service.dart';
import '../models/current_user.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TenantService _tenantService = TenantService();
  final CurrentUserService _userService = CurrentUserService();

  CurrentUser? _user;
  List<Tenant> _tenants = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _userService.getCurrentUser(),
        _tenantService.getTenants(),
      ]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as CurrentUser;
        _tenants = results[1] as List<Tenant>;
        _error = null;
        _loading = false;
      });
    } on AccessBlockedException {
      // ApiClient ya redirigió a la pantalla de acceso bloqueado.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = TenantUi.errorMessage(e);
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Navegación
  // ---------------------------------------------------------------------------

  Future<void> _openDetail(Tenant tenant) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TenantDetailPage(tenantId: tenant.id)),
    );
    if (mounted) await _load();
  }

  Future<void> _openList({String? filter}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TenantsListPage(initialFilter: filter)),
    );
    if (mounted) await _load();
  }

  Future<void> _openNewTenant() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TenantFormPage()),
    );
    if (created == true && mounted) await _load();
  }

  // ---------------------------------------------------------------------------
  // Datos calculados
  // ---------------------------------------------------------------------------

  int _count(bool Function(Tenant) test) => _tenants.where(test).length;

  List<Tenant> get _recent {
    final sorted = [..._tenants];
    sorted.sort((a, b) {
      final da = a.creadoEn ?? DateTime(1970);
      final db = b.creadoEn ?? DateTime(1970);
      return db.compareTo(da);
    });
    return sorted.take(5).toList();
  }

  // ---------------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final user = _user!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
        children: user.isSuperAdmin ? _superAdminContent(user) : _memberContent(user),
      ),
    );
  }

  Widget _header(CurrentUser user, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            Text(
              'Bienvenido, ${user.saludo}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.titleColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.inputBorder),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 14, color: AppTheme.accentDark),
                  const SizedBox(width: 4),
                  Text(
                    user.rolPrincipal,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
      ],
    );
  }

  // ---------------------------- SuperAdmin -----------------------------------

  List<Widget> _superAdminContent(CurrentUser user) {
    final total = _tenants.length;
    final activas = _count((t) => t.estado == 'ACTIVO');
    final pendientes = _count((t) => t.estado == 'PENDIENTE');
    final inactivas = _count((t) => t.estado == 'INACTIVO' || t.estado == 'SUSPENDIDO');
    final porcentaje = total == 0 ? 0 : (activas * 100 / total).round();

    return [
      _header(user, 'Supervisión global de la plataforma y control de empresas adheridas.'),
      const SizedBox(height: 18),
      if (pendientes > 0) ...[
        _pendingBanner(pendientes),
        const SizedBox(height: 18),
      ],
      GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 128,
        ),
        children: [
          _kpiCard('Registradas', '$total', 'En SITUR-SMART', Icons.apartment, AppTheme.titleColor,
              onTap: () => _openList()),
          _kpiCard('Activas', '$activas', '$porcentaje% de la red', Icons.check_circle_outline, TenantUi.green,
              onTap: () => _openList(filter: 'ACTIVO')),
          _kpiCard('Pendientes', '$pendientes', 'Requieren revisión', Icons.schedule, TenantUi.amber,
              onTap: () => _openList(filter: 'PENDIENTE')),
          _kpiCard('Inactivas o pausadas', '$inactivas', 'Suspendidas o inactivas', Icons.pause_circle_outline,
              TenantUi.blueGrey,
              onTap: () => _openList(filter: 'INACTIVAS')),
        ],
      ),
      const SizedBox(height: 22),
      _recentCard(),
      const SizedBox(height: 22),
      _actionsCard(),
    ];
  }

  Widget _pendingBanner(int pendientes) {
    final text = pendientes == 1
        ? '1 empresa pendiente de activación'
        : '$pendientes empresas pendientes de activación';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: TenantUi.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Revisa sus datos y habilita sus cuentas de propietario.',
            style: TextStyle(color: Color(0xFF92400E), fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF9A3412)),
              onPressed: () => _openList(filter: 'PENDIENTE'),
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Revisar pendientes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(
    String title,
    String value,
    String caption,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.inputBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color),
              ),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentCard() {
    final recent = _recent;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Registradas recientemente',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => _openList(),
                child: Text('Ver todas (${_tenants.length})'),
              ),
            ],
          ),
          const Text(
            'Últimas organizaciones incorporadas a la plataforma.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Todavía no hay empresas registradas.'),
            ),
          ...recent.map(_tenantRow),
        ],
      ),
    );
  }

  Widget _tenantRow(Tenant tenant) {
    final details = <String>[
      if (tenant.ciudad != null) tenant.ciudad!,
      tenant.suscripcionPlan == null
          ? 'Sin suscripción'
          : '${tenant.suscripcionPlan} · ${tenant.suscripcionEstado}',
    ].join(' · ');

    return InkWell(
      onTap: () => _openDetail(tenant),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            TenantUi.avatar(tenant.iniciales),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        tenant.nombreComercial,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      TenantUi.statusChip(tenant.estado),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _actionsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.panelBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones de plataforma',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Operaciones reservadas para el SuperAdmin.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          _actionButton(Icons.add_business_outlined, 'Nueva empresa', _openNewTenant),
          const SizedBox(height: 10),
          _actionButton(Icons.apartment, 'Administrar empresas', () => _openList()),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------- Otros usuarios --------------------------------

  List<Widget> _memberContent(CurrentUser user) {
    return [
      _header(user, 'Resumen de tu empresa en SITUR-SMART.'),
      const SizedBox(height: 22),
      const Text(
        'Mis empresas',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      if (_tenants.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Tu cuenta no está asociada a ninguna empresa.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ..._tenants.map(
        (tenant) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _tenantRow(tenant),
          ),
        ),
      ),
    ];
  }
}