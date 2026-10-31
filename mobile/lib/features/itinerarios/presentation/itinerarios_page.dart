import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/itinerario_service.dart';
import '../models/itinerario.dart';
import 'itinerario_detalle_page.dart';
import 'itinerario_form_page.dart';

/// Lista de itinerarios del turista (los mismos que ve en la web).
class ItinerariosPage extends StatefulWidget {
  const ItinerariosPage({super.key});

  @override
  State<ItinerariosPage> createState() => _ItinerariosPageState();
}

class _ItinerariosPageState extends State<ItinerariosPage> {
  final ItinerarioService _service = ItinerarioService();

  List<Itinerario> _itinerarios = [];
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
      final itinerarios = await _service.getItinerarios();
      if (!mounted) return;
      setState(() {
        _itinerarios = itinerarios;
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

  Future<void> _nuevo() async {
    final creado = await Navigator.of(context).push<Itinerario>(
      MaterialPageRoute(builder: (_) => const ItinerarioFormPage()),
    );
    if (creado == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ItinerarioDetallePage(itinerarioId: creado.id)),
    );
    if (mounted) _cargar();
  }

  Future<void> _abrir(Itinerario itinerario) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ItinerarioDetallePage(itinerarioId: itinerario.id)),
    );
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Itinerarios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo viaje'),
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _itinerarios.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _itinerarios.isEmpty) {
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

    if (_itinerarios.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: const [
            SizedBox(height: 60),
            Icon(Icons.map_outlined, size: 56, color: AppTheme.accentDark),
            SizedBox(height: 16),
            Text(
              'Organiza tu próximo viaje',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Crea un itinerario con las fechas de tu viaje y agrega actividades día por día.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _itinerarios.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _TarjetaItinerario(
          itinerario: _itinerarios[index],
          onTap: () => _abrir(_itinerarios[index]),
        ),
      ),
    );
  }
}

class _TarjetaItinerario extends StatelessWidget {
  const _TarjetaItinerario({required this.itinerario, required this.onTap});

  final Itinerario itinerario;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final terminado = itinerario.estadoTexto == 'Terminado';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.inputBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.demoBg, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.map_outlined, color: AppTheme.accentDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(itinerario.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      Fechas.rango(itinerario.inicio, itinerario.fin),
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (itinerario.ciudad != null) itinerario.ciudad!,
                        itinerario.dias == 1 ? '1 día' : '${itinerario.dias} días',
                        itinerario.actividades == 1 ? '1 actividad' : '${itinerario.actividades} actividades',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: terminado ? AppTheme.inputBorder : AppTheme.demoBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  itinerario.estadoTexto,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: terminado ? AppTheme.textSecondary : AppTheme.accentDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}