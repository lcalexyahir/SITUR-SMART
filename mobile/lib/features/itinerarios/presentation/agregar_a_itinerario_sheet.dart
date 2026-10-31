import 'package:flutter/material.dart';

import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/itinerario_service.dart';
import '../models/itinerario.dart';
import 'actividad_form_sheet.dart';
import 'itinerario_form_page.dart';

/// Desde la ficha de un producto: elegir viaje y día para agregarlo.
Future<void> mostrarAgregarAItinerario(
  BuildContext context, {
  required int productoId,
  required String productoNombre,
}) async {
  final agregado = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _AgregarAItinerario(productoId: productoId, productoNombre: productoNombre),
  );
  if (agregado != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Se agregó a "$agregado".')),
    );
  }
}

class _AgregarAItinerario extends StatefulWidget {
  const _AgregarAItinerario({required this.productoId, required this.productoNombre});

  final int productoId;
  final String productoNombre;

  @override
  State<_AgregarAItinerario> createState() => _AgregarAItinerarioState();
}

class _AgregarAItinerarioState extends State<_AgregarAItinerario> {
  final ItinerarioService _service = ItinerarioService();

  List<Itinerario>? _itinerarios;
  Itinerario? _elegido;
  DateTime? _fecha;
  TimeOfDay? _hora;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final hoy = Fechas.soloFecha(DateTime.now());
      // Solo viajes que no terminaron.
      final todos = await _service.getItinerarios();
      final vigentes = todos.where((it) => !it.fin.isBefore(hoy)).toList();
      if (!mounted) return;
      setState(() {
        _itinerarios = vigentes;
        if (vigentes.isNotEmpty) _elegir(vigentes.first);
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    }
  }

  void _elegir(Itinerario itinerario) {
    _elegido = itinerario;
    final hoy = Fechas.soloFecha(DateTime.now());
    _fecha = itinerario.fechas.firstWhere((f) => !f.isBefore(hoy), orElse: () => itinerario.inicio);
  }

  Future<void> _nuevoViaje() async {
    final creado = await Navigator.of(context).push<Itinerario>(
      MaterialPageRoute(builder: (_) => const ItinerarioFormPage()),
    );
    if (creado == null || !mounted) return;
    setState(() {
      _itinerarios = [creado, ...?_itinerarios];
      _elegir(creado);
    });
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: _hora ?? const TimeOfDay(hour: 9, minute: 0),
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (hora != null) setState(() => _hora = hora);
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _service.agregarActividad(
        _elegido!.id,
        fecha: _fecha!,
        hora: _hora == null ? null : horaATexto(_hora!),
        productoId: widget.productoId,
      );
      if (mounted) Navigator.of(context).pop(_elegido!.nombre);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final itinerarios = _itinerarios;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Agregar a mi itinerario',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.titleColor),
          ),
          const SizedBox(height: 4),
          Text(widget.productoNombre, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          if (itinerarios == null && _error == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (itinerarios != null && itinerarios.isEmpty) ...[
            const Text('No tienes viajes próximos. Crea uno para organizar este producto.'),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _nuevoViaje, icon: const Icon(Icons.add), label: const Text('Crear viaje')),
          ] else if (itinerarios != null) ...[
            DropdownButtonFormField<int>(
              key: ValueKey('viajes-${itinerarios.length}'),
              initialValue: _elegido?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Viaje', prefixIcon: Icon(Icons.map_outlined)),
              items: [
                for (final it in itinerarios)
                  DropdownMenuItem(
                    value: it.id,
                    child: Text('${it.nombre} (${Fechas.rango(it.inicio, it.fin)})', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => setState(() => _elegir(itinerarios.firstWhere((it) => it.id == id))),
            ),
            const SizedBox(height: 16),
            if (_elegido != null)
              DropdownButtonFormField<DateTime>(
                key: ValueKey('dias-${_elegido!.id}'),
                initialValue: _fecha,
                decoration: const InputDecoration(labelText: 'Día', prefixIcon: Icon(Icons.event_outlined)),
                items: [
                  for (final fecha in _elegido!.fechas)
                    DropdownMenuItem(value: fecha, child: Text(Fechas.conDia(fecha))),
                ],
                onChanged: (fecha) => setState(() => _fecha = fecha),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _guardando ? null : _elegirHora,
              icon: const Icon(Icons.schedule),
              label: Text(_hora == null ? 'Agregar hora (opcional)' : 'Hora: ${horaATexto(_hora!)}'),
            ),
            TextButton.icon(onPressed: _nuevoViaje, icon: const Icon(Icons.add), label: const Text('Crear otro viaje')),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _guardando || _elegido == null || _fecha == null ? null : _guardar,
              child: Text(_guardando ? 'Agregando...' : 'Agregar'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
          ],
        ],
      ),
    );
  }
}