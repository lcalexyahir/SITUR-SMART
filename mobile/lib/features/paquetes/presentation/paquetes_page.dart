import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../../itinerarios/models/itinerario.dart';
import '../data/paquete_service.dart';
import '../models/paquete.dart';
import 'paquete_detalle_page.dart';
import 'paquete_form_page.dart';

/// "Mis paquetes": paquetes personalizados que arma el turista (CU39).
class PaquetesPage extends StatefulWidget {
  const PaquetesPage({super.key});

  @override
  State<PaquetesPage> createState() => _PaquetesPageState();
}

class _PaquetesPageState extends State<PaquetesPage> {
  final PaqueteService _service = PaqueteService();

  List<Paquete> _paquetes = [];
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
      final paquetes = await _service.getPaquetes();
      if (!mounted) return;
      setState(() {
        _paquetes = paquetes;
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

  Future<void> _abrir(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaqueteDetallePage(paqueteId: id)));
    if (mounted) _cargar();
  }

  Future<void> _nuevo() async {
    final creado = await Navigator.of(context).push<Paquete>(
      MaterialPageRoute(builder: (_) => const PaqueteFormPage()),
    );
    if (creado != null && mounted) _abrir(creado.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis paquetes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Armar paquete'),
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _paquetes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _paquetes.isEmpty) {
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
    if (_paquetes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: const [
            SizedBox(height: 60),
            Icon(Icons.card_giftcard, size: 56, color: AppTheme.accentDark),
            SizedBox(height: 16),
            Text(
              'Arma tu propio paquete',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Junta hospedaje, tours, restaurantes y atracciones en un solo viaje y mira cuánto cuesta.',
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
        itemCount: _paquetes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final paquete = _paquetes[index];
          return _TarjetaPaquete(paquete: paquete, onTap: () => _abrir(paquete.id));
        },
      ),
    );
  }
}

class _TarjetaPaquete extends StatelessWidget {
  const _TarjetaPaquete({required this.paquete, required this.onTap});

  final Paquete paquete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final comprado = paquete.compra != null;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(paquete.nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: comprado ? const Color(0xFFDCFCE7) : AppTheme.demoBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      paquete.estadoTexto,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: comprado ? const Color(0xFF166534) : AppTheme.accentDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  Fechas.rango(paquete.inicio, paquete.fin),
                  paquete.personas == 1 ? '1 viajero' : '${paquete.personas} viajeros',
                  if (paquete.ciudad != null) paquete.ciudad!,
                ].join(' · '),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    paquete.cantidadServicios == 1 ? '1 servicio' : '${paquete.cantidadServicios} servicios',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    paquete.totalTexto,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.titleColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}