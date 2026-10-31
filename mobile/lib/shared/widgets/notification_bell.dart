import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/notificaciones/data/notificacion_service.dart';
import '../../features/notificaciones/presentation/notificaciones_page.dart';

/// Campana de la barra superior con la cantidad de avisos sin leer (CU45).
/// Se actualiza al abrir la app, al volver a ella y cada minuto.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.color = Colors.white});

  final Color color;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with WidgetsBindingObserver {
  static const Duration _intervalo = Duration(minutes: 1);

  final NotificacionService _service = NotificacionService();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refrescar();
    _timer = Timer.periodic(_intervalo, (_) => _refrescar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refrescar();
  }

  Future<void> _refrescar() async {
    try {
      await _service.refrescarContador();
    } catch (_) {
      // Sin conexión o sesión cerrada: la campana conserva el último valor.
    }
  }

  Future<void> _abrir() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificacionesPage()),
    );
    _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificacionService.noLeidas,
      builder: (context, cantidad, _) {
        return IconButton(
          tooltip: cantidad == 0 ? 'Notificaciones' : 'Notificaciones: $cantidad sin leer',
          onPressed: _abrir,
          icon: Badge(
            isLabelVisible: cantidad > 0,
            label: Text(cantidad > 99 ? '99+' : '$cantidad'),
            child: Icon(
              cantidad > 0 ? Icons.notifications_active : Icons.notifications_none,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}