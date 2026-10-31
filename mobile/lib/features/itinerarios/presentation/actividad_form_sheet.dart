import 'package:flutter/material.dart';

import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/itinerario_service.dart';
import '../models/itinerario.dart';

/// Formulario para agregar o editar una actividad libre de un itinerario.
/// Devuelve true si se guardó.
Future<bool> mostrarFormularioActividad(
  BuildContext context, {
  required Itinerario itinerario,
  DateTime? dia,
  Actividad? actividad,
}) async {
  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ActividadForm(itinerario: itinerario, dia: dia, actividad: actividad),
  );
  return guardado ?? false;
}

/// Convierte "HH:MM" en TimeOfDay y viceversa.
TimeOfDay? horaDesdeTexto(String? valor) {
  if (valor == null || !valor.contains(':')) return null;
  final partes = valor.split(':');
  return TimeOfDay(hour: int.tryParse(partes[0]) ?? 0, minute: int.tryParse(partes[1]) ?? 0);
}

String horaATexto(TimeOfDay hora) =>
    '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

class _ActividadForm extends StatefulWidget {
  const _ActividadForm({required this.itinerario, this.dia, this.actividad});

  final Itinerario itinerario;
  final DateTime? dia;
  final Actividad? actividad;

  @override
  State<_ActividadForm> createState() => _ActividadFormState();
}

class _ActividadFormState extends State<_ActividadForm> {
  final ItinerarioService _service = ItinerarioService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _nota;

  late DateTime _fecha;
  TimeOfDay? _hora;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.actividad != null;

  @override
  void initState() {
    super.initState();
    final act = widget.actividad;
    _titulo = TextEditingController(text: act?.titulo ?? '');
    _nota = TextEditingController(text: act?.nota ?? '');
    _fecha = act?.fecha ?? widget.dia ?? widget.itinerario.inicio;
    _hora = horaDesdeTexto(act?.hora);
  }

  @override
  void dispose() {
    _titulo.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _elegirHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: _hora ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Hora de la actividad',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (hora != null) setState(() => _hora = hora);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final hora = _hora == null ? null : horaATexto(_hora!);
      if (_editando) {
        await _service.editarActividad(
          widget.itinerario.id,
          widget.actividad!.id,
          fecha: _fecha,
          hora: hora,
          titulo: _titulo.text,
          nota: _nota.text,
        );
      } else {
        await _service.agregarActividad(
          widget.itinerario.id,
          fecha: _fecha,
          hora: hora,
          titulo: _titulo.text,
          nota: _nota.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
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
    final fechas = widget.itinerario.fechas;
    final teclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + teclado),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editando ? 'Editar actividad' : 'Nueva actividad',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.titleColor),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titulo,
                enabled: !_guardando,
                maxLength: 150,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿Qué vas a hacer?',
                  hintText: 'Ej.: Almuerzo en el mercado',
                  prefixIcon: Icon(Icons.edit_note),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe qué vas a hacer.' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<DateTime>(
                initialValue: fechas.contains(_fecha) ? _fecha : fechas.first,
                decoration: const InputDecoration(labelText: 'Día', prefixIcon: Icon(Icons.event_outlined)),
                items: [
                  for (var i = 0; i < fechas.length; i++)
                    DropdownMenuItem(value: fechas[i], child: Text('Día ${i + 1} · ${Fechas.conDia(fechas[i])}')),
                ],
                onChanged: _guardando ? null : (fecha) => setState(() => _fecha = fecha ?? _fecha),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _guardando ? null : _elegirHora,
                      icon: const Icon(Icons.schedule),
                      label: Text(_hora == null ? 'Agregar hora (opcional)' : 'Hora: ${horaATexto(_hora!)}'),
                    ),
                  ),
                  if (_hora != null)
                    IconButton(
                      tooltip: 'Quitar hora',
                      onPressed: _guardando ? null : () => setState(() => _hora = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nota,
                enabled: !_guardando,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Nota (opcional)', alignLabelWithHint: true),
              ),
              if (_error != null) Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: Text(_guardando ? 'Guardando...' : (_editando ? 'Guardar cambios' : 'Agregar actividad')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}