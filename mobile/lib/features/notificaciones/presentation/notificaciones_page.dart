import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/notificacion_service.dart';
import '../models/notificacion.dart';

/// Bandeja de notificaciones y recordatorios del usuario (CU45).
/// Los avisos los generan la web y su backend (reservas, pagos, recordatorios
/// previos); la app los muestra porque comparten la misma base de datos.
class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  final NotificacionService _service = NotificacionService();

  /// Al cambiar, las pestañas vuelven a cargar su lista.
  int _version = 0;
  bool _procesando = false;

  Future<void> _accionMasiva(String accion) async {
    if (accion == 'limpiar') {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Eliminar avisos leídos'),
          content: const Text('Se borrarán de tu bandeja todas las notificaciones que ya leíste.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (confirmar != true) return;
    }

    setState(() => _procesando = true);
    try {
      if (accion == 'leer') {
        await _service.marcarTodasLeidas();
      } else {
        await _service.eliminarLeidas();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accion == 'leer' ? 'Todas las notificaciones quedaron leídas.' : 'Se eliminaron los avisos leídos.'),
        ),
      );
      setState(() => _version++);
    } on AccessBlockedException {
      // ApiClient ya redirigió.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notificaciones'),
          actions: [
            if (_procesando)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'Más opciones',
                onSelected: _accionMasiva,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'leer',
                    child: ListTile(
                      leading: Icon(Icons.done_all),
                      title: Text('Marcar todas como leídas'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'limpiar',
                    child: ListTile(
                      leading: Icon(Icons.delete_sweep_outlined),
                      title: Text('Eliminar las leídas'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
          ],
          bottom: TabBar(
            labelColor: AppTheme.accentDark,
            indicatorColor: AppTheme.accentDark,
            tabs: [
              const Tab(text: 'Todas'),
              Tab(
                child: ValueListenableBuilder<int>(
                  valueListenable: NotificacionService.noLeidas,
                  builder: (context, cantidad, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No leídas'),
                      if (cantidad > 0) ...[
                        const SizedBox(width: 6),
                        Badge(label: Text(cantidad > 99 ? '99+' : '$cantidad')),
                      ],
                    ],
                  ),
                ),
              ),
              const Tab(text: 'Recordatorios'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final filtro in FiltroNotificaciones.values)
              _ListaNotificaciones(
                key: ValueKey('${filtro.name}-$_version'),
                filtro: filtro,
              ),
          ],
        ),
      ),
    );
  }
}

/// Lista de una pestaña, paginada, con "deslizar para eliminar".
class _ListaNotificaciones extends StatefulWidget {
  const _ListaNotificaciones({super.key, required this.filtro});

  final FiltroNotificaciones filtro;

  @override
  State<_ListaNotificaciones> createState() => _ListaNotificacionesState();
}

class _ListaNotificacionesState extends State<_ListaNotificaciones> {
  final NotificacionService _service = NotificacionService();
  final ScrollController _scroll = ScrollController();
  final List<Notificacion> _items = [];

  int _pagina = 1;
  bool _haySiguiente = false;
  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _cargarMas();
    });
    _cargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _service.getNotificaciones(filtro: widget.filtro);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(datos.resultados);
        _pagina = 1;
        _haySiguiente = datos.haySiguiente;
        _cargando = false;
      });
      _service.refrescarContador().ignore();
    } on AccessBlockedException {
      // ApiClient ya redirigió.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _cargando = false;
      });
    }
  }

  Future<void> _cargarMas() async {
    if (!_haySiguiente || _cargandoMas || _cargando) return;
    setState(() => _cargandoMas = true);
    try {
      final datos = await _service.getNotificaciones(filtro: widget.filtro, page: _pagina + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(datos.resultados);
        _pagina++;
        _haySiguiente = datos.haySiguiente;
        _cargandoMas = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  Future<void> _abrir(int index) async {
    var aviso = _items[index];
    if (!aviso.leida) {
      // Se marca leída de inmediato en pantalla y luego en el servidor.
      setState(() => _items[index] = aviso.copiaLeida());
      try {
        await _service.marcarLeida(aviso.id);
      } catch (_) {
        // Si falla, la próxima carga la mostrará otra vez como no leída.
      }
      aviso = aviso.copiaLeida();
    }
    if (!mounted) return;
    await _mostrarDetalle(aviso);

    // En "No leídas" el aviso ya no corresponde a esta pestaña.
    if (mounted && widget.filtro == FiltroNotificaciones.noLeidas) {
      setState(() => _items.removeWhere((item) => item.id == aviso.id));
    }
  }

  Future<void> _mostrarDetalle(Notificacion aviso) {
    final formato = DateFormat('dd/MM/yyyy HH:mm');
    final inicio = aviso.inicio;

    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconoAviso(aviso: aviso, radio: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aviso.etiquetaTipo.toUpperCase(),
                        style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: aviso.color),
                      ),
                      Text(formato.format(aviso.creadoEn), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(aviso.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.titleColor)),
            const SizedBox(height: 8),
            Text(aviso.mensaje, style: const TextStyle(fontSize: 15, height: 1.5, color: AppTheme.labelColor)),
            if (aviso.codigoReserva != null || inicio != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.demoBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.demoBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (aviso.codigoReserva != null)
                      _Dato(icono: Icons.confirmation_number_outlined, texto: 'Código de reserva: ${aviso.codigoReserva}'),
                    if (inicio != null)
                      _Dato(icono: Icons.event_outlined, texto: 'Inicio: ${formato.format(inicio)}'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _eliminar(Notificacion aviso) async {
    try {
      await _service.eliminar(aviso.id);
      return true;
    } on AccessBlockedException {
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: AppTheme.errorColor),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Icon(_vacio.$1, size: 56, color: AppTheme.accentDark),
            const SizedBox(height: 16),
            Text(
              _vacio.$2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _vacio.$3,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length + (_cargandoMas ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final aviso = _items[index];
          return Dismissible(
            key: ValueKey('aviso-${aviso.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: AppTheme.errorColor,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            confirmDismiss: (_) => _eliminar(aviso),
            onDismissed: (_) {
              setState(() => _items.removeWhere((item) => item.id == aviso.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notificación eliminada.')),
              );
            },
            child: _FilaAviso(aviso: aviso, onTap: () => _abrir(index)),
          );
        },
      ),
    );
  }

  (IconData, String, String) get _vacio {
    switch (widget.filtro) {
      case FiltroNotificaciones.noLeidas:
        return (Icons.mark_email_read_outlined, 'Estás al día', 'No tienes notificaciones sin leer.');
      case FiltroNotificaciones.recordatorios:
        return (
          Icons.alarm_outlined,
          'Sin recordatorios',
          'Te avisaremos un día antes y dos horas antes del inicio de cada reserva confirmada.',
        );
      case FiltroNotificaciones.todas:
        return (
          Icons.notifications_none,
          'No tienes notificaciones',
          'Aquí verás las confirmaciones de reserva, los recordatorios y las novedades de tus viajes.',
        );
    }
  }
}

class _FilaAviso extends StatelessWidget {
  const _FilaAviso({required this.aviso, required this.onTap});

  final Notificacion aviso;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: aviso.leida ? Colors.white : AppTheme.demoBg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconoAviso(aviso: aviso),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            aviso.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: aviso.leida ? FontWeight.w500 : FontWeight.w800,
                              color: AppTheme.titleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(aviso.tiempoRelativo, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      aviso.mensaje,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.35, color: AppTheme.labelColor),
                    ),
                  ],
                ),
              ),
              if (!aviso.leida)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(color: AppTheme.accentDark, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconoAviso extends StatelessWidget {
  const _IconoAviso({required this.aviso, this.radio = 20});

  final Notificacion aviso;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radio,
      backgroundColor: aviso.color.withValues(alpha: 0.12),
      child: Icon(aviso.icono, color: aviso.color, size: radio),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icono, size: 18, color: AppTheme.accentDark),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}