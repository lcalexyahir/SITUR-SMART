import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/pago_service.dart';
import '../models/pago.dart';

/// "Mis pagos": historial de los pagos hechos en la web. Solo consulta.
class MisPagosPage extends StatefulWidget {
  const MisPagosPage({super.key});

  @override
  State<MisPagosPage> createState() => _MisPagosPageState();
}

class _MisPagosPageState extends State<MisPagosPage> {
  static const Map<String?, String> _filtros = {
    null: 'Todos',
    'APROBADO': 'Aprobados',
    'PENDIENTE': 'Pendientes',
    'RECHAZADO': 'Rechazados',
  };

  final PagoService _service = PagoService();
  final ScrollController _scroll = ScrollController();
  final DateFormat _fecha = DateFormat('dd/MM/yyyy HH:mm');
  final List<Pago> _pagos = [];

  List<ResumenPagos> _resumen = [];
  String? _estado;
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
      final datos = await _service.getPagos(estado: _estado);
      if (!mounted) return;
      setState(() {
        _pagos
          ..clear()
          ..addAll(datos.pagos);
        _resumen = datos.resumen;
        _pagina = 1;
        _haySiguiente = datos.haySiguiente;
        _cargando = false;
      });
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
      final datos = await _service.getPagos(estado: _estado, page: _pagina + 1);
      if (!mounted) return;
      setState(() {
        _pagos.addAll(datos.pagos);
        _pagina++;
        _haySiguiente = datos.haySiguiente;
        _cargandoMas = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  void _detalle(Pago pago) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(pago.icono, color: pago.color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(pago.montoTexto, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                Text(pago.estadoTexto, style: TextStyle(color: pago.color, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            _Dato('Producto', pago.producto ?? '—'),
            _Dato('Empresa', pago.empresa),
            _Dato('Reserva', pago.reservaCodigo),
            _Dato('Método', '${pago.metodoTexto} · ${pago.proveedor}'),
            _Dato('Fecha', _fecha.format(pago.creadoEn)),
            if (pago.procesadoEn != null) _Dato('Procesado', _fecha.format(pago.procesadoEn!)),
            if (pago.reembolsos.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Reembolsos', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              for (final reembolso in pago.reembolsos)
                Text(
                  '${pago.simbolo} ${reembolso.monto} · ${reembolso.estadoTexto}'
                  '${(reembolso.motivo ?? '').isNotEmpty ? ' · ${reembolso.motivo}' : ''}',
                  style: const TextStyle(color: AppTheme.labelColor, height: 1.5),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pagos')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final filtro in _filtros.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(filtro.value),
                      selected: _estado == filtro.key,
                      onSelected: (_) {
                        setState(() => _estado = filtro.key);
                        _cargar();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _pagos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _pagos.isEmpty) {
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

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (_resumen.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.accentDark, AppTheme.panelBg]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL PAGADO', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  for (final r in _resumen)
                    Text(
                      '${r.simbolo} ${r.total}  ·  ${r.pagos == 1 ? '1 pago' : '${r.pagos} pagos'}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_pagos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.accentDark),
                  SizedBox(height: 16),
                  Text('Sin pagos registrados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'Aquí aparecerán los pagos de las reservas que hagas desde la web.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          else
            for (final pago in _pagos)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppTheme.inputBorder),
                ),
                child: ListTile(
                  onTap: () => _detalle(pago),
                  leading: CircleAvatar(
                    backgroundColor: pago.color.withValues(alpha: 0.12),
                    child: Icon(pago.icono, color: pago.color),
                  ),
                  title: Text(pago.producto ?? 'Reserva ${pago.reservaCodigo}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${_fecha.format(pago.creadoEn)} · ${pago.metodoTexto}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(pago.montoTexto, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(pago.estadoTexto, style: TextStyle(fontSize: 12, color: pago.color)),
                    ],
                  ),
                ),
              ),
          if (_cargandoMas)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(etiqueta, style: const TextStyle(color: AppTheme.textSecondary))),
          Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}