import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/itinerarios/models/itinerario.dart';

/// Campo de solo lectura que abre el calendario. Lo usan itinerarios y paquetes.
class CampoFecha extends StatelessWidget {
  const CampoFecha({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.onChanged,
    this.primera,
    this.ultima,
    this.icono = Icons.event_outlined,
    this.enabled = true,
  });

  final String etiqueta;
  final DateTime? valor;
  final ValueChanged<DateTime> onChanged;
  final DateTime? primera;
  final DateTime? ultima;
  final IconData icono;
  final bool enabled;

  Future<void> _elegir(BuildContext context) async {
    final hoy = Fechas.soloFecha(DateTime.now());
    final desde = primera ?? hoy;
    final hasta = ultima ?? DateTime(hoy.year + 2, hoy.month, hoy.day);
    var inicial = valor ?? desde;
    if (inicial.isBefore(desde)) inicial = desde;
    if (inicial.isAfter(hasta)) inicial = hasta;
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: desde,
      lastDate: hasta,
      helpText: etiqueta,
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (elegida != null) onChanged(Fechas.soloFecha(elegida));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _elegir(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: Icon(icono),
          enabled: enabled,
        ),
        child: Text(
          valor == null ? 'Elegir fecha' : Fechas.conDia(valor!),
          style: TextStyle(color: valor == null ? AppTheme.textSecondary : AppTheme.titleColor),
        ),
      ),
    );
  }
}

/// Selector de ciudad opcional (con "Sin ciudad").
class CampoCiudad extends StatelessWidget {
  const CampoCiudad({
    super.key,
    required this.ciudades,
    required this.valor,
    required this.onChanged,
    this.etiqueta = 'Ciudad (opcional)',
  });

  final List<Ciudad> ciudades;
  final int? valor;
  final ValueChanged<int?> onChanged;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final existe = valor == null || ciudades.any((c) => c.id == valor);
    return DropdownButtonFormField<int?>(
      // Se reconstruye cuando llegan las ciudades para mostrar la elegida.
      key: ValueKey('ciudades-${ciudades.length}'),
      initialValue: existe ? valor : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: etiqueta, prefixIcon: const Icon(Icons.location_city_outlined)),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Sin ciudad')),
        for (final ciudad in ciudades)
          DropdownMenuItem<int?>(value: ciudad.id, child: Text(ciudad.etiqueta, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }
}