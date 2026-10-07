import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/subscription_service.dart';
import '../models/subscription.dart';

class TenantSubscriptionPage extends StatefulWidget {
  const TenantSubscriptionPage({
    super.key,
    required this.tenantId,
    required this.tenantName,
  });

  final int tenantId;
  final String tenantName;

  @override
  State<TenantSubscriptionPage> createState() => _TenantSubscriptionPageState();
}

class _TenantSubscriptionPageState extends State<TenantSubscriptionPage> {
  final SubscriptionService _service = SubscriptionService();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  static const List<int> _monthOptions = [1, 3, 6, 12];

  TenantSubscriptionInfo? _info;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await _service.getTenantSubscription(widget.tenantId);
      if (!mounted) return;
      setState(() {
        _info = info;
        _loading = false;
      });
    } on SubscriptionInactiveException {
      // ApiClient ya redirigió a la pantalla de suscripción inactiva.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = SubscriptionService.errorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _runAction(Future<void> Function() action, String successMessage) async {
    setState(() => _working = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      await _load();
    } on SubscriptionInactiveException {
      // ApiClient ya redirigió a la pantalla de suscripción inactiva.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SubscriptionService.errorMessage(e)),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Acciones (solo SuperAdmin)
  // ---------------------------------------------------------------------------

  Future<void> _openAssignDialog() async {
    List<PlanModel> plans;
    try {
      plans = await _service.getPlans();
    } on SubscriptionInactiveException {
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SubscriptionService.errorMessage(e))),
      );
      return;
    }

    if (!mounted) return;

    if (plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay planes activos registrados.')),
      );
      return;
    }

    PlanModel selectedPlan = plans.first;
    int selectedMonths = _monthOptions.first;
    bool autoRenew = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Asignar plan'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<PlanModel>(
                      initialValue: selectedPlan,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Plan'),
                      items: plans
                          .map(
                            (plan) => DropdownMenuItem(
                              value: plan,
                              child: Text('${plan.nombre} (${plan.precioTexto})'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedPlan = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedMonths,
                      decoration: const InputDecoration(labelText: 'Duración'),
                      items: _monthOptions
                          .map(
                            (months) => DropdownMenuItem(
                              value: months,
                              child: Text(months == 1 ? '1 mes' : '$months meses'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedMonths = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Renovación automática'),
                      value: autoRenew,
                      onChanged: (value) => setDialogState(() => autoRenew = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Asignar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    await _runAction(
      () => _service.assign(
        tenantId: widget.tenantId,
        planId: selectedPlan.id,
        meses: selectedMonths,
        renovacionAutomatica: autoRenew,
      ),
      'Plan asignado correctamente.',
    );
  }

  Future<void> _openRenewDialog() async {
    int selectedMonths = _monthOptions.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Renovar suscripción'),
              content: DropdownButtonFormField<int>(
                initialValue: selectedMonths,
                decoration: const InputDecoration(labelText: 'Extender por'),
                items: _monthOptions
                    .map(
                      (months) => DropdownMenuItem(
                        value: months,
                        child: Text(months == 1 ? '1 mes' : '$months meses'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedMonths = value);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Renovar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    await _runAction(
      () => _service.renew(tenantId: widget.tenantId, meses: selectedMonths),
      'Suscripción renovada correctamente.',
    );
  }

  Future<void> _confirmSuspend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Suspender suscripción'),
        content: Text(
          'Los usuarios de ${widget.tenantName} no podrán usar el sistema '
          'hasta que la suscripción se renueve. ¿Desea continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Suspender'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _runAction(
      () => _service.suspend(tenantId: widget.tenantId),
      'Suscripción suspendida.',
    );
  }

  // ---------------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------------

  Color _statusColor(String estado) {
    switch (estado) {
      case 'ACTIVA':
        return const Color(0xFF16A34A);
      case 'VENCIDA':
        return const Color(0xFFF59E0B);
      case 'SUSPENDIDA':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  Widget _statusChip(String estado) {
    final color = _statusColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  String _formatDate(DateTime? date) => date == null ? 'Sin fecha' : _dateFormat.format(date);

  Widget _currentCard(TenantSubscriptionInfo info) {
    final current = info.actual;

    if (current == null) {
      final last = info.historial.isNotEmpty ? info.historial.first : null;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sin suscripción activa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                last == null
                    ? 'Esta empresa todavía no tiene un plan asignado.'
                    : 'Última suscripción: ${last.plan.nombre} (${last.estado}).',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    current.plan.nombre,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                _statusChip(current.estado),
              ],
            ),
            const SizedBox(height: 4),
            Text(current.plan.precioTexto, style: const TextStyle(color: AppTheme.textSecondary)),
            const Divider(height: 28),
            _infoRow('Inicio', _formatDate(current.fechaInicio)),
            _infoRow('Vence', _formatDate(current.fechaFin)),
            if (current.diasRestantes != null) _infoRow('Días restantes', '${current.diasRestantes}'),
            _infoRow('Renovación automática', current.renovacionAutomatica ? 'Sí' : 'No'),
            _infoRow('Usuarios permitidos', '${current.plan.maxUsuarios}'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  List<Widget> _actions(TenantSubscriptionInfo info) {
    if (!info.puedeGestionar) return const [];

    final hasActive = info.actual != null;
    final hasHistory = info.historial.isNotEmpty;

    return [
      const SizedBox(height: 16),
      if (!hasActive)
        FilledButton.icon(
          onPressed: _working ? null : _openAssignDialog,
          icon: const Icon(Icons.add_card),
          label: const Text('Asignar plan'),
        ),
      if (hasActive || hasHistory) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _working ? null : _openRenewDialog,
          icon: const Icon(Icons.autorenew),
          label: const Text('Renovar'),
        ),
      ],
      if (hasActive) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor),
          onPressed: _working ? null : _confirmSuspend,
          icon: const Icon(Icons.block),
          label: const Text('Suspender'),
        ),
      ],
    ];
  }

  Widget _historyList(TenantSubscriptionInfo info) {
    if (info.historial.isEmpty) {
      return const Text(
        'Sin registros.',
        style: TextStyle(color: AppTheme.textSecondary),
      );
    }

    return Column(
      children: info.historial
          .map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long, color: AppTheme.accentDark),
              title: Text(item.plan.nombre),
              subtitle: Text('${_formatDate(item.fechaInicio)} - ${_formatDate(item.fechaFin)}'),
              trailing: _statusChip(item.estado),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Suscripción - ${widget.tenantName}'),
      ),
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
              OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final info = _info!;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _currentCard(info),
              ..._actions(info),
              const SizedBox(height: 28),
              const Text(
                'Historial',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _historyList(info),
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
}