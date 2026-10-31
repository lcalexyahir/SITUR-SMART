import 'package:flutter/material.dart';

import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/campos_viaje.dart';
import '../data/itinerario_service.dart';
import '../models/itinerario.dart';

/// Crear o editar un itinerario. Devuelve el itinerario guardado.
class ItinerarioFormPage extends StatefulWidget {
  const ItinerarioFormPage({super.key, this.itinerario});

  final Itinerario? itinerario;

  @override
  State<ItinerarioFormPage> createState() => _ItinerarioFormPageState();
}

class _ItinerarioFormPageState extends State<ItinerarioFormPage> {
  final ItinerarioService _service = ItinerarioService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _notas;

  List<Ciudad> _ciudades = [];
  int? _ciudadId;
  DateTime? _inicio;
  DateTime? _fin;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.itinerario != null;

  @override
  void initState() {
    super.initState();
    final it = widget.itinerario;
    _nombre = TextEditingController(text: it?.nombre ?? '');
    _notas = TextEditingController(text: it?.notas ?? '');
    _ciudadId = it?.ciudadId;
    _inicio = it?.inicio;
    _fin = it?.fin;
    _service.getCiudades().then((ciudades) {
      if (mounted) setState(() => _ciudades = ciudades);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _nombre.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_inicio == null || _fin == null) {
      setState(() => _error = 'Elige la fecha de salida y la de regreso.');
      return;
    }
    if (_fin!.isBefore(_inicio!)) {
      setState(() => _error = 'La fecha de regreso no puede ser anterior a la de salida.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final guardado = _editando
          ? await _service.editar(
              widget.itinerario!.id,
              nombre: _nombre.text,
              inicio: _inicio!,
              fin: _fin!,
              ciudadId: _ciudadId,
              notas: _notas.text,
            )
          : await _service.crear(
              nombre: _nombre.text,
              inicio: _inicio!,
              fin: _fin!,
              ciudadId: _ciudadId,
              notas: _notas.text,
            );
      if (mounted) Navigator.of(context).pop(guardado);
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
    // Al editar se permiten fechas pasadas (el viaje pudo empezar ya).
    final primera = _editando ? DateTime(2020) : null;

    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar itinerario' : 'Nuevo itinerario')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _nombre,
                enabled: !_guardando,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre del viaje',
                  hintText: 'Ej.: Fin de semana en Samaipata',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Ponle un nombre a tu viaje.' : null,
              ),
              const SizedBox(height: 8),
              CampoFecha(
                etiqueta: 'Salida',
                valor: _inicio,
                primera: primera,
                enabled: !_guardando,
                onChanged: (fecha) => setState(() {
                  _inicio = fecha;
                  if (_fin != null && _fin!.isBefore(fecha)) _fin = fecha;
                }),
              ),
              const SizedBox(height: 16),
              CampoFecha(
                etiqueta: 'Regreso',
                valor: _fin,
                primera: _inicio ?? primera,
                enabled: !_guardando,
                icono: Icons.event_available_outlined,
                onChanged: (fecha) => setState(() => _fin = fecha),
              ),
              const SizedBox(height: 16),
              CampoCiudad(
                ciudades: _ciudades,
                valor: _ciudadId,
                onChanged: (id) => setState(() => _ciudadId = id),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notas,
                enabled: !_guardando,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  hintText: 'Qué llevar, contactos, ideas...',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(_editando ? 'Guardar cambios' : 'Crear itinerario'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}