import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../../itinerarios/models/itinerario.dart';
import '../data/paquete_service.dart';
import '../models/paquete.dart';
import 'agregar_servicio_page.dart';
import 'paquete_form_page.dart';

/// Detalle de un paquete: servicios, total y cotización.
class PaqueteDetallePage extends StatefulWidget {
  const PaqueteDetallePage({super.key, required this.paqueteId});

  final int paqueteId;

  @override
  State<PaqueteDetallePage> createState() => _PaqueteDetallePageState();
}

class _PaqueteDetallePageState extends State<PaqueteDetallePage> {
  final PaqueteService _service = PaqueteService();

  Paquete? _paquete;
  bool _cargando = true;
  bool _procesando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final paquete = await _service.getPaquete(widget.paqueteId);
      if (!mounted) return;
      setState(() {
        _paquete = paquete;
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

  void _avisar(String texto, {bool error = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? AppTheme.errorColor : null),
    );
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() => _procesando = true);
    try {
      await accion();
    } on AccessBlockedException {
      // ApiClient ya redirigió.
    } catch (e) {
      if (mounted) _avisar(apiErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _agregar() async {
    final agregado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AgregarServicioPage(paquete: _paquete!)),
    );
    if (agregado == true && mounted) {
      _avisar('Servicio agregado al paquete.');
      _cargar();
    }
  }

  Future<void> _quitar(ComponentePaquete componente) => _ejecutar(() async {
        await _service.quitarServicio(widget.paqueteId, componente.id);
        if (!mounted) return;
        _avisar('Se quitó ${componente.nombre}.');
        await _cargar();
      });

  Future<void> _cotizar({required bool guardar}) => _ejecutar(() async {
        final paquete = await _service.cotizar(widget.paqueteId, guardar: guardar);
        if (!mounted) return;
        setState(() => _paquete = paquete);
        _avisar(guardar ? 'Paquete cotizado y guardado: ${paquete.totalTexto}.' : 'Precios actualizados.');
      });

  Future<void> _editar() async {
    final editado = await Navigator.of(context).push<Paquete>(
      MaterialPageRoute(builder: (_) => PaqueteFormPage(paquete: _paquete)),
    );
    if (editado != null && mounted) {
      _avisar('Paquete actualizado.');
      _cargar();
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar paquete'),
        content: Text('Se eliminará "${_paquete!.nombre}" con todos sus servicios.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await _ejecutar(() async {
      await _service.eliminar(widget.paqueteId);
      if (!mounted) return;
      _avisar('Paquete eliminado.');
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final paquete = _paquete;
    final editable = paquete?.editable ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(paquete?.nombre ?? 'Paquete'),
        actions: [
          if (paquete != null && editable)
            PopupMenuButton<String>(
              onSelected: (opcion) => opcion == 'editar' ? _editar() : _eliminar(),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'editar',
                  child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar datos'), contentPadding: EdgeInsets.zero),
                ),
                PopupMenuItem(
                  value: 'eliminar',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: AppTheme.errorColor),
                    title: Text('Eliminar paquete'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _cuerpo(),
      bottomNavigationBar: paquete == null ? null : _barraInferior(paquete),
    );
  }

  Widget _barraInferior(Paquete paquete) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.inputBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Total estimado', style: TextStyle(color: AppTheme.textSecondary)),
                const Spacer(),
                Text(
                  paquete.compra != null ? 'Bs ${paquete.compra!.total}' : paquete.totalTexto,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.titleColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (paquete.editable)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _procesando || paquete.componentes.isEmpty ? null : () => _cotizar(guardar: false),
                      child: const Text('Recotizar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _procesando || paquete.componentes.isEmpty ? null : () => _cotizar(guardar: true),
                      child: Text(_procesando ? 'Procesando...' : 'Guardar cotización'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Text(
              paquete.editable
                  ? 'La compra del paquete se realiza desde la web de SITUR-SMART.'
                  : 'Este paquete ya tiene una compra y no se puede modificar.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _paquete == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _paquete == null) {
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

    final paquete = _paquete!;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _Resumen(paquete: paquete),
          if (paquete.advertencias.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Algunos servicios necesitan revisión',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final aviso in paquete.advertencias)
                    Text('• $aviso', style: const TextStyle(color: Color(0xFF92400E), height: 1.4)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text('Servicios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (paquete.editable)
                TextButton.icon(
                  onPressed: _procesando ? null : _agregar,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (paquete.componentes.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.demoBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.demoBorder),
              ),
              child: Column(
                children: [
                  const Icon(Icons.add_shopping_cart, color: AppTheme.accentDark, size: 36),
                  const SizedBox(height: 8),
                  const Text(
                    'Tu paquete todavía está vacío. Agrega hospedaje, tours, restaurantes o atracciones.',
                    textAlign: TextAlign.center,
                  ),
                  if (paquete.editable) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _agregar, icon: const Icon(Icons.add), label: const Text('Agregar servicio')),
                  ],
                ],
              ),
            )
          else
            for (final componente in paquete.componentes) ...[
              _TarjetaComponente(
                componente: componente,
                onQuitar: paquete.editable && !_procesando ? () => _quitar(componente) : null,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.paquete});

  final Paquete paquete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.accentDark, AppTheme.panelBg]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            paquete.estadoTexto.toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(paquete.nombre, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            [
              Fechas.rango(paquete.inicio, paquete.fin),
              paquete.personas == 1 ? '1 viajero' : '${paquete.personas} viajeros',
              if (paquete.ciudad != null) paquete.ciudad!,
            ].join(' · '),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _TarjetaComponente extends StatelessWidget {
  const _TarjetaComponente({required this.componente, this.onQuitar});

  final ComponentePaquete componente;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    final problema = !componente.disponible;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: problema ? const Color(0xFFFCD34D) : AppTheme.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: (componente.imagenUrl ?? '').startsWith('http')
                  ? Image.network(
                      componente.imagenUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _IconoServicio(),
                    )
                  : const _IconoServicio(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  componente.tipo.toUpperCase(),
                  style: const TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: AppTheme.accentDark),
                ),
                Text(componente.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(componente.empresa, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(componente.fechasTexto, style: const TextStyle(fontSize: 13)),
                Text(componente.detalle, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                if (componente.motivo != null) ...[
                  const SizedBox(height: 4),
                  Text(componente.motivo!, style: const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Bs ${componente.total}', style: const TextStyle(fontWeight: FontWeight.w800)),
              if (onQuitar != null)
                IconButton(
                  tooltip: 'Quitar del paquete',
                  onPressed: onQuitar,
                  icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconoServicio extends StatelessWidget {
  const _IconoServicio();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.demoBg,
      child: const Icon(Icons.landscape_outlined, color: AppTheme.accentDark),
    );
  }
}