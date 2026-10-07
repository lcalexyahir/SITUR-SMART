import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/tenant_service.dart';
import '../models/tenant.dart';
import 'tenant_detail_page.dart';
import 'tenant_ui.dart';

/// Lista completa de empresas con búsqueda y filtro por estado.
/// Filtros: null (todas), ACTIVO, PENDIENTE, INACTIVAS (suspendidas + inactivas).
class TenantsListPage extends StatefulWidget {
  const TenantsListPage({
    super.key,
    this.initialFilter,
  });

  final String? initialFilter;

  @override
  State<TenantsListPage> createState() => _TenantsListPageState();
}

class _TenantsListPageState extends State<TenantsListPage> {
  final TenantService _service = TenantService();
  final TextEditingController _search = TextEditingController();

  static const Map<String?, String> _filters = {
    null: 'Todas',
    'ACTIVO': 'Activas',
    'PENDIENTE': 'Pendientes',
    'INACTIVAS': 'Inactivas o pausadas',
  };

  List<Tenant> _tenants = [];
  String? _filter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final tenants = await _service.getTenants();
      if (!mounted) return;
      setState(() {
        _tenants = tenants;
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

  bool _matchesFilter(Tenant tenant) {
    switch (_filter) {
      case null:
        return true;
      case 'INACTIVAS':
        return tenant.estado == 'INACTIVO' || tenant.estado == 'SUSPENDIDO';
      default:
        return tenant.estado == _filter;
    }
  }

  bool _matchesSearch(Tenant tenant) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return tenant.nombreComercial.toLowerCase().contains(query) ||
        tenant.razonSocial.toLowerCase().contains(query) ||
        (tenant.ciudad ?? '').toLowerCase().contains(query) ||
        tenant.subdomain.toLowerCase().contains(query);
  }

  Future<void> _openDetail(Tenant tenant) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TenantDetailPage(tenantId: tenant.id)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Empresas')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    final visible = _tenants.where((t) => _matchesFilter(t) && _matchesSearch(t)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, ciudad o identificador',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _filters.entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _filter == entry.key,
                      onSelected: (_) => setState(() => _filter = entry.key),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: visible.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No hay empresas que coincidan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final tenant = visible[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        onTap: () => _openDetail(tenant),
                        leading: TenantUi.avatar(tenant.iniciales),
                        title: Text(
                          tenant.nombreComercial,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          [
                            if (tenant.ciudad != null) tenant.ciudad!,
                            tenant.suscripcionPlan ?? 'Sin suscripción',
                          ].join(' · '),
                        ),
                        trailing: TenantUi.statusChip(tenant.estado),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}