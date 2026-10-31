import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../../catalogo/models/product.dart';
import '../../catalogo/presentation/explore_page.dart';
import '../../itinerarios/models/itinerario.dart';
import '../data/paquete_service.dart';
import '../models/paquete.dart';

/// Buscar un servicio y configurarlo para sumarlo al paquete.
/// Devuelve true cuando se agregó.
class AgregarServicioPage extends StatefulWidget {
  const AgregarServicioPage({super.key, required this.paquete});

  final Paquete paquete;

  @override
  State<AgregarServicioPage> createState() => _AgregarServicioPageState();
}

class _AgregarServicioPageState extends State<AgregarServicioPage> {
  final PaqueteService _service = PaqueteService();
  final TextEditingController _busqueda = TextEditingController();
  Timer? _espera;

  List<Product> _productos = [];
  String? _tipo;
  late bool _soloCiudad;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _soloCiudad = widget.paquete.ciudadId != null;
    _cargar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  void _alEscribir(String _) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), _cargar);
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final productos = await _service.getCatalogo(
        texto: _busqueda.text,
        tipo: _tipo,
        ciudadId: _soloCiudad ? widget.paquete.ciudadId : null,
      );
      if (!mounted) return;
      setState(() {
        _productos = productos;
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

  Future<void> _configurar(Product producto) async {
    final agregado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ServicioForm(paquete: widget.paquete, producto: producto),
    );
    if (agregado == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar servicio')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _busqueda,
              onChanged: _alEscribir,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _cargar(),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, empresa o ciudad',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('Todos', null),
                for (final entry in tiposServicio.entries) _chip(entry.value, entry.key),
              ],
            ),
          ),
          if (widget.paquete.ciudadId != null)
            SwitchListTile(
              dense: true,
              value: _soloCiudad,
              title: Text('Solo en ${widget.paquete.ciudad}'),
              onChanged: (valor) {
                setState(() => _soloCiudad = valor);
                _cargar();
              },
            ),
          const Divider(height: 1),
          Expanded(child: _lista()),
        ],
      ),
    );
  }

  Widget _chip(String etiqueta, String? codigo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(etiqueta),
        selected: _tipo == codigo,
        onSelected: (_) {
          setState(() => _tipo = codigo);
          _cargar();
        },
      ),
    );
  }

  Widget _lista() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
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
    if (_productos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay servicios con esos filtros.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _productos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final producto = _productos[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _configurar(producto),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.inputBorder),
              ),
              child: Row(
                children: [
                  SizedBox(width: 90, height: 90, child: ProductImage(product: producto, height: 90)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            producto.tipo.nombre.toUpperCase(),
                            style: const TextStyle(fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: AppTheme.accentDark),
                          ),
                          Text(producto.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(producto.ubicacion, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(producto.precioTexto, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(
                          producto.tipo.codigo == 'HABITACION' ? 'por noche' : 'por persona',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fechas, cantidad y huéspedes del servicio elegido.
class _ServicioForm extends StatefulWidget {
  const _ServicioForm({required this.paquete, required this.producto});

  final Paquete paquete;
  final Product producto;

  @override
  State<_ServicioForm> createState() => _ServicioFormState();
}

class _ServicioFormState extends State<_ServicioForm> {
  final PaqueteService _service = PaqueteService();

  late DateTime _inicio;
  DateTime? _fin;
  int _cantidad = 1;
  int _huespedes = 1;
  bool _guardando = false;
  String? _error;

  bool get _esHospedaje => widget.producto.tipo.codigo == 'HABITACION';

  /// Días del viaje desde hoy.
  List<DateTime> get _dias {
    final hoy = Fechas.soloFecha(DateTime.now());
    return widget.paquete.fechas.where((d) => !d.isBefore(hoy)).toList();
  }

  /// Salida del hospedaje: hasta el día siguiente al fin del viaje.
  List<DateTime> get _salidas {
    final ultimo = widget.paquete.fin.add(const Duration(days: 1));
    final salidas = <DateTime>[];
    var dia = DateTime(_inicio.year, _inicio.month, _inicio.day + 1);
    while (!dia.isAfter(ultimo)) {
      salidas.add(dia);
      dia = DateTime(dia.year, dia.month, dia.day + 1);
    }
    return salidas;
  }

  int get _maxCantidad => _esHospedaje
      ? widget.paquete.personas
      : math.min(widget.paquete.personas, math.max(1, widget.producto.capacidadMaxima));

  @override
  void initState() {
    super.initState();
    final dias = _dias;
    _inicio = dias.isNotEmpty ? dias.first : widget.paquete.inicio;
    _cantidad = _esHospedaje ? 1 : _maxCantidad;
    _huespedes = widget.paquete.personas;
    if (_esHospedaje) _fin = _salidas.isNotEmpty ? _salidas.first : null;
  }

  double get _estimado {
    final precio = double.tryParse(widget.producto.precio) ?? 0;
    if (_esHospedaje) {
      final noches = _fin == null ? 0 : _fin!.difference(_inicio).inDays;
      return precio * _cantidad * noches;
    }
    return precio * _cantidad;
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _service.agregarServicio(
        widget.paquete.id,
        productoId: widget.producto.id,
        inicio: _inicio,
        fin: _esHospedaje ? _fin : null,
        cantidad: _cantidad,
        huespedes: _esHospedaje ? _huespedes : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  Widget _contador(String etiqueta, int valor, int minimo, int maximo, ValueChanged<int> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(labelText: etiqueta),
      child: Row(
        children: [
          Text('$valor', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            onPressed: _guardando || valor <= minimo ? null : () => onChanged(valor - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            onPressed: _guardando || valor >= maximo ? null : () => onChanged(valor + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dias = _dias;
    if (dias.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Las fechas de este paquete ya pasaron. Edita el paquete para elegir nuevas fechas.'),
      );
    }
    final salidas = _salidas;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.producto.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.titleColor)),
            Text(
              '${widget.producto.precioTexto} ${_esHospedaje ? 'por noche' : 'por persona'} · ${widget.producto.empresaNombre}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DateTime>(
              initialValue: _inicio,
              decoration: InputDecoration(
                labelText: _esHospedaje ? 'Llegada' : 'Día',
                prefixIcon: const Icon(Icons.event_outlined),
              ),
              items: [for (final d in dias) DropdownMenuItem(value: d, child: Text(Fechas.conDia(d)))],
              onChanged: _guardando
                  ? null
                  : (fecha) => setState(() {
                        _inicio = fecha ?? _inicio;
                        if (_esHospedaje && (_fin == null || !_fin!.isAfter(_inicio))) {
                          final nuevas = _salidas;
                          _fin = nuevas.isNotEmpty ? nuevas.first : null;
                        }
                      }),
            ),
            if (_esHospedaje) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<DateTime>(
                key: ValueKey('salida-${Fechas.api(_inicio)}'),
                initialValue: salidas.contains(_fin) ? _fin : null,
                decoration: const InputDecoration(labelText: 'Salida', prefixIcon: Icon(Icons.event_available_outlined)),
                items: [
                  for (final d in salidas)
                    DropdownMenuItem(
                      value: d,
                      child: Text('${Fechas.conDia(d)} (${d.difference(_inicio).inDays} noches)'),
                    ),
                ],
                onChanged: _guardando ? null : (fecha) => setState(() => _fin = fecha),
              ),
              const SizedBox(height: 16),
              _contador('Habitaciones', _cantidad, 1, _maxCantidad, (v) => setState(() {
                    _cantidad = v;
                    if (_huespedes < v) _huespedes = v;
                  })),
              const SizedBox(height: 16),
              _contador('Huéspedes', _huespedes, _cantidad, widget.paquete.personas, (v) => setState(() => _huespedes = v)),
            ] else ...[
              const SizedBox(height: 16),
              _contador('Personas', _cantidad, 1, _maxCantidad, (v) => setState(() => _cantidad = v)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Subtotal estimado', style: TextStyle(color: AppTheme.textSecondary)),
                const Spacer(),
                Text(
                  '${widget.producto.moneda} ${_estimado.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _guardando || (_esHospedaje && _fin == null) ? null : _guardar,
              icon: const Icon(Icons.add),
              label: Text(_guardando ? 'Agregando...' : 'Agregar al paquete'),
            ),
          ],
        ),
      ),
    );
  }
}