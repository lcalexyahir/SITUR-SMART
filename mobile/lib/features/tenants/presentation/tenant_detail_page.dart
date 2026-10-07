import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../suscripciones/presentation/tenant_subscription_page.dart';
import '../data/tenant_service.dart';
import '../models/tenant.dart';
import 'tenant_edit_page.dart';
import 'tenant_ui.dart';

class TenantDetailPage extends StatefulWidget {
  const TenantDetailPage({
    super.key,
    required this.tenantId,
  });

  final int tenantId;

  @override
  State<TenantDetailPage> createState() => _TenantDetailPageState();
}

class _TenantDetailPageState extends State<TenantDetailPage> {
  final TenantService _service = TenantService();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  static const Map<String, String> _statusDescriptions = {
    'ACTIVO': 'La empresa puede operar normalmente.',
    'PENDIENTE': 'La empresa espera revisión y activación de la plataforma.',
    'SUSPENDIDO': 'Sus usuarios pueden ingresar, pero no operar dentro de esta empresa.',
    'INACTIVO': 'La empresa no opera hasta que la plataforma la reactive.',
  };

  Tenant? _tenant;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tenant = await _service.getTenant(widget.tenantId);
      if (!mounted) return;
      setState(() {
        _tenant = tenant;
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
  // Acciones
  // ---------------------------------------------------------------------------

  Future<void> _edit(Tenant tenant) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TenantEditPage(tenant: tenant)),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información actualizada.')),
      );
      await _load();
    }
  }

  Future<void> _openSubscription(Tenant tenant) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TenantSubscriptionPage(
          tenantId: tenant.id,
          tenantName: tenant.nombreComercial,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _changeStatus(Tenant tenant, String estado, String titulo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Text(
          '${tenant.nombreComercial}: ${_statusDescriptions[estado]}\n\n¿Desea continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: estado == 'ACTIVO'
                ? null
                : FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _working = true);
    try {
      final updated = await _service.changeStatus(tenant.id, estado);
      if (!mounted) return;
      setState(() => _tenant = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado actualizado: ${TenantUi.statusLabel(estado)}.')),
      );
    } on AccessBlockedException {
      // ApiClient ya redirigió a la pantalla de acceso bloqueado.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TenantUi.errorMessage(e)),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Empresa')),
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

    final tenant = _tenant!;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _headerCard(tenant),
              const SizedBox(height: 14),
              _generalCard(tenant),
              const SizedBox(height: 14),
              _statusCard(tenant),
              const SizedBox(height: 14),
              _ownerCard(tenant),
              const SizedBox(height: 14),
              _subscriptionCard(tenant),
            ],
          ),
        ),
        if (_working)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _section({
    required String title,
    String? subtitle,
    Widget? action,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              if (action != null) action,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _field(String label, String? value, {IconData? icon}) {
    final text = (value == null || value.trim().isEmpty) ? 'Sin registrar' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
              ],
              Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerCard(Tenant tenant) {
    return _section(
      title: tenant.nombreComercial,
      action: TenantUi.statusChip(tenant.estado),
      children: [
        Text(tenant.razonSocial, style: const TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place_outlined, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(tenant.ciudad ?? 'Ciudad sin registrar'),
              ],
            ),
            if (tenant.creadoEn != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text('Registrada el ${_dateFormat.format(tenant.creadoEn!)}'),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _generalCard(Tenant tenant) {
    return _section(
      title: 'Información general',
      subtitle: 'Identidad y datos de contacto.',
      action: tenant.puedeGestionar
          ? TextButton.icon(
              onPressed: _working ? null : () => _edit(tenant),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
            )
          : null,
      children: [
        _field('Nombre comercial', tenant.nombreComercial),
        _field('Razón social', tenant.razonSocial),
        _field('NIT', tenant.nit),
        _field('Identificador web', tenant.subdomain),
        _field('Correo de contacto', tenant.emailContacto, icon: Icons.mail_outline),
        _field('Teléfono', tenant.telefono, icon: Icons.phone_outlined),
      ],
    );
  }

  Widget _statusCard(Tenant tenant) {
    final options = <(String, String, String)>[
      ('ACTIVO', 'Activar empresa', 'La empresa podrá operar normalmente.'),
      ('SUSPENDIDO', 'Suspender temporalmente', 'Sus usuarios podrán ingresar, pero no operar.'),
      ('INACTIVO', 'Marcar como inactiva', 'Dejará de operar hasta que la plataforma la reactive.'),
    ].where((option) => option.$1 != tenant.estado).toList();

    final color = TenantUi.statusColor(tenant.estado);

    return _section(
      title: 'Estado operativo',
      subtitle: 'Controla si la empresa puede trabajar en SITUR-SMART.',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 10, color: color),
                  const SizedBox(width: 8),
                  Text(
                    TenantUi.statusLabel(tenant.estado),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(_statusDescriptions[tenant.estado] ?? ''),
            ],
          ),
        ),
        if (tenant.puedeGestionar)
          ...options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _working ? null : () => _changeStatus(tenant, option.$1, option.$2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.$2,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.titleColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.$3,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _ownerCard(Tenant tenant) {
    final owner = tenant.propietario;
    return _section(
      title: 'Propietario',
      subtitle: 'Cuenta responsable de administrar esta empresa.',
      children: [
        if (owner == null)
          const Text('Sin propietario asignado.', style: TextStyle(color: AppTheme.textSecondary))
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: AppTheme.demoBg,
              child: Icon(Icons.person_outline, color: AppTheme.accentDark),
            ),
            title: Text(
              owner.nombre.isEmpty ? owner.email : owner.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(owner.email),
          ),
      ],
    );
  }

  Widget _subscriptionCard(Tenant tenant) {
    final hasSubscription = tenant.suscripcionEstado != null;
    final vence = tenant.suscripcionFin == null ? 'Sin fecha' : _dateFormat.format(tenant.suscripcionFin!);

    return _section(
      title: 'Suscripción',
      subtitle: 'Condiciones contratadas por la empresa.',
      children: [
        if (!hasSubscription)
          const Text('La empresa no tiene un plan asignado.', style: TextStyle(color: AppTheme.textSecondary))
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  tenant.suscripcionPlan ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              TenantUi.chip(
                tenant.suscripcionEstado!,
                TenantUi.subscriptionColor(tenant.suscripcionEstado),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Vence: $vence', style: const TextStyle(color: AppTheme.textSecondary)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _working ? null : () => _openSubscription(tenant),
            icon: const Icon(Icons.credit_card),
            label: Text(tenant.puedeGestionar ? 'Gestionar suscripción' : 'Ver suscripción'),
          ),
        ),
      ],
    );
  }
}