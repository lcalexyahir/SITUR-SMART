import 'package:flutter/material.dart';

import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/campos_viaje.dart';
import '../../itinerarios/data/itinerario_service.dart';
import '../../itinerarios/models/itinerario.dart';
import '../data/paquete_service.dart';
import '../models/paquete.dart';

/// Datos generales del paquete: nombre, fechas, viajeros y ciudad.
class PaqueteFormPage extends StatefulWidget {
  const PaqueteFormPage({super.key, this.paquete});

  final Paquete? paquete;

  @override
  State<PaqueteFormPage> createState() => _PaqueteFormPageState();
}

class _PaqueteFormPageState extends State<PaqueteFormPage> {
  final PaqueteService _service = PaqueteService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;

  List<Ciudad> _ciudades = [];
  int? _ciudadId;
  DateTime? _inicio;
  DateTime? _fin;
  int _personas = 2;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.paquete != null;

  @override
  void initState() {
    super.initState();
    final p = widget.paquete;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _ciudadId = p?.ciudadId;
    _inicio = p?.inicio;
    _fin = p?.fin;
    _personas = p?.personas ?? 2;
    ItinerarioService().getCiudades().then((ciudades) {
      if (mounted) setState(() => _ciudades = ciudades);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_inicio == null || _fin == null) {
      setState(() => _error = 'Elige la fecha de inicio y la de fin del viaje.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final paquete = _editando
          ? await _service.editar(
              widget.paquete!.id,
              nombre: _nombre.text,
              inicio: _inicio!,
              fin: _fin!,
              personas: _personas,
              ciudadId: _ciudadId,
            )
          : await _service.crear(
              nombre: _nombre.text,
              inicio: _inicio!,
              fin: _fin!,
              personas: _personas,
              ciudadId: _ciudadId,
            );
      if (mounted) Navigator.of(context).pop(paquete);
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
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar paquete' : 'Armar paquete')),
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
                  labelText: 'Nombre del paquete',
                  hintText: 'Ej.: Aventura en Samaipata',
                  prefixIcon: Icon(Icons.card_giftcard),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Ponle un nombre a tu paquete.' : null,
              ),
              const SizedBox(height: 8),
              CampoFecha(
                etiqueta: 'Inicio del viaje',
                valor: _inicio,
                enabled: !_guardando,
                onChanged: (fecha) => setState(() {
                  _inicio = fecha;
                  if (_fin != null && _fin!.isBefore(fecha)) _fin = fecha;
                }),
              ),
              const SizedBox(height: 16),
              CampoFecha(
                etiqueta: 'Fin del viaje',
                valor: _fin,
                primera: _inicio,
                enabled: !_guardando,
                icono: Icons.event_available_outlined,
                onChanged: (fecha) => setState(() => _fin = fecha),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Viajeros', prefixIcon: Icon(Icons.groups_outlined)),
                child: Row(
                  children: [
                    Text('$_personas', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Menos viajeros',
                      onPressed: _guardando || _personas <= 1 ? null : () => setState(() => _personas--),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'Más viajeros',
                      onPressed: _guardando || _personas >= 50 ? null : () => setState(() => _personas++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CampoCiudad(
                ciudades: _ciudades,
                valor: _ciudadId,
                etiqueta: 'Ciudad principal (opcional)',
                onChanged: (id) => setState(() => _ciudadId = id),
              ),
              if (_editando) ...[
                const SizedBox(height: 12),
                const Text(
                  'Si cambias fechas o viajeros, los servicios se vuelven a cotizar.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: const Icon(Icons.check),
                label: Text(_guardando ? 'Guardando...' : (_editando ? 'Guardar cambios' : 'Continuar')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}