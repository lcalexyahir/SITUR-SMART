import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/itinerario_service.dart';
import '../models/itinerario.dart';
import 'actividad_form_sheet.dart';
import 'itinerario_form_page.dart';

/// Itinerario día por día con sus actividades.
class ItinerarioDetallePage extends StatefulWidget {
  const ItinerarioDetallePage({super.key, required this.itinerarioId});

  final int itinerarioId;

  @override
  State<ItinerarioDetallePage> createState() => _ItinerarioDetallePageState();
}

class _ItinerarioDetallePageState extends State<ItinerarioDetallePage> {
  final ItinerarioService _service = ItinerarioService();

  Itinerario? _itinerario;
  bool _cargando = true;
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
      final itinerario = await _service.getItinerario(widget.itinerarioId);
      if (!mounted) return;
      setState(() {
        _itinerario = itinerario;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? AppTheme.errorColor : null),
    );
  }

  Future<void> _editar() async {
    final editado = await Navigator.of(context).push<Itinerario>(
      MaterialPageRoute(builder: (_) => ItinerarioFormPage(itinerario: _itinerario)),
    );
    if (editado != null && mounted) {
      _avisar('Itinerario actualizado.');
      _cargar();
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar itinerario'),
        content: Text('Se eliminará "${_itinerario!.nombre}" con todas sus actividades.'),
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
    try {
      await _service.eliminar(widget.itinerarioId);
      if (!mounted) return;
      _avisar('Itinerario eliminado.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _avisar(apiErrorMessage(e), error: true);
    }
  }

  Future<void> _agregarActividad(DateTime dia) async {
    if (await mostrarFormularioActividad(context, itinerario: _itinerario!, dia: dia)) _cargar();
  }

  Future<void> _editarActividad(Actividad actividad) async {
    if (await mostrarFormularioActividad(context, itinerario: _itinerario!, actividad: actividad)) _cargar();
  }

  Future<void> _eliminarActividad(Actividad actividad) async {
    try {
      await _service.eliminarActividad(widget.itinerarioId, actividad.id);
      if (!mounted) return;
      _avisar('Actividad eliminada.');
      _cargar();
    } catch (e) {
      if (mounted) _avisar(apiErrorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itinerario = _itinerario;
    return Scaffold(
      appBar: AppBar(
        title: Text(itinerario?.nombre ?? 'Itinerario'),
        actions: [
          if (itinerario != null)
            PopupMenuButton<String>(
              onSelected: (opcion) => opcion == 'editar' ? _editar() : _eliminar(),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'editar',
                  child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar viaje'), contentPadding: EdgeInsets.zero),
                ),
                PopupMenuItem(
                  value: 'eliminar',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: AppTheme.errorColor),
                    title: Text('Eliminar viaje'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _itinerario == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _itinerario == null) {
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

    final itinerario = _itinerario!;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Cabecera(itinerario: itinerario),
          const SizedBox(height: 16),
          for (var i = 0; i < itinerario.diasDetalle.length; i++) ...[
            _DiaCard(
              numero: i + 1,
              dia: itinerario.diasDetalle[i],
              onAgregar: () => _agregarActividad(itinerario.diasDetalle[i].fecha),
              onEditar: _editarActividad,
              onEliminar: _eliminarActividad,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.itinerario});

  final Itinerario itinerario;

  @override
  Widget build(BuildContext context) {
    final notas = (itinerario.notas ?? '').trim();
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
            itinerario.estadoTexto.toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(itinerario.nombre, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '${Fechas.rango(itinerario.inicio, itinerario.fin)} · ${itinerario.dias == 1 ? '1 día' : '${itinerario.dias} días'}'
            '${itinerario.ciudad != null ? ' · ${itinerario.ciudad}' : ''}',
            style: const TextStyle(color: Colors.white),
          ),
          if (notas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(notas, style: const TextStyle(color: Colors.white70, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _DiaCard extends StatelessWidget {
  const _DiaCard({
    required this.numero,
    required this.dia,
    required this.onAgregar,
    required this.onEditar,
    required this.onEliminar,
  });

  final int numero;
  final DiaItinerario dia;
  final VoidCallback onAgregar;
  final ValueChanged<Actividad> onEditar;
  final ValueChanged<Actividad> onEliminar;

  Widget? _subtitulo(Actividad actividad) {
    final texto = [
      if (actividad.producto != null) actividad.producto!.tipo,
      if ((actividad.nota ?? '').trim().isNotEmpty) actividad.nota!.trim(),
    ].join(' · ');
    if (texto.isEmpty) return null;
    return Text(texto, maxLines: 2, overflow: TextOverflow.ellipsis);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.demoBg,
                  child: Text('$numero', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentDark)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${Fechas.dia(dia.fecha)} ${Fechas.corta(dia.fecha)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                TextButton.icon(onPressed: onAgregar, icon: const Icon(Icons.add, size: 18), label: const Text('Agregar')),
              ],
            ),
          ),
          if (dia.actividades.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text('Día libre. Toca "Agregar" para planear algo.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            for (final actividad in dia.actividades)
              ListTile(
                leading: SizedBox(
                  width: 48,
                  child: Text(
                    actividad.hora ?? '—',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.accentDark),
                  ),
                ),
                title: Text(actividad.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: _subtitulo(actividad),
                trailing: PopupMenuButton<String>(
                  onSelected: (opcion) {
                    if (opcion == 'editar') {
                      onEditar(actividad);
                    } else {
                      onEliminar(actividad);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'editar', child: Text('Editar')),
                    PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                  ],
                ),
              ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}