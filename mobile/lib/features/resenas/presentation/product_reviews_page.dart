import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/resena_service.dart';
import '../models/resena.dart';
import 'resena_form_sheet.dart';
import 'widgets/resena_tile.dart';

/// Todas las reseñas de un producto, cargadas por páginas al hacer scroll.
class ProductReviewsPage extends StatefulWidget {
  const ProductReviewsPage({
    super.key,
    required this.productoId,
    required this.productoNombre,
  });

  final int productoId;
  final String productoNombre;

  @override
  State<ProductReviewsPage> createState() => _ProductReviewsPageState();
}

class _ProductReviewsPageState extends State<ProductReviewsPage> {
  final ResenaService _service = ResenaService();
  final ScrollController _scroll = ScrollController();
  final List<Resena> _resenas = [];

  ResumenResenas? _resumen;
  int _pagina = 1;
  bool _haySiguiente = false;
  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alHacerScroll);
    _cargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _alHacerScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      _cargarMas();
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final pagina = await _service.getResenasProducto(widget.productoId);
      if (!mounted) return;
      setState(() {
        _resumen = pagina.resumen;
        _resenas
          ..clear()
          ..addAll(pagina.resultados);
        _pagina = 1;
        _haySiguiente = pagina.haySiguiente;
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

  Future<void> _cargarMas() async {
    if (!_haySiguiente || _cargandoMas || _cargando) return;
    setState(() => _cargandoMas = true);
    try {
      final pagina = await _service.getResenasProducto(widget.productoId, page: _pagina + 1);
      if (!mounted) return;
      setState(() {
        _resenas.addAll(pagina.resultados);
        _pagina++;
        _haySiguiente = pagina.haySiguiente;
        _cargandoMas = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  Future<void> _editar(Resena resena) async {
    final guardado = await mostrarFormularioResena(
      context,
      productoId: widget.productoId,
      productoNombre: widget.productoNombre,
      resena: resena,
    );
    if (guardado && mounted) _cargar();
  }

  Future<void> _eliminar(Resena resena) async {
    if (await confirmarEliminarResena(context, resena)) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reseñas')),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _resumen == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _resumen == null) {
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

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _resenas.length + 2,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.productoNombre,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.titleColor),
                ),
                const SizedBox(height: 12),
                ResumenResenasCard(resumen: _resumen!),
              ],
            );
          }
          if (index == _resenas.length + 1) {
            if (_cargandoMas) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_resenas.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Este producto todavía no tiene reseñas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final resena = _resenas[index - 1];
          return ResenaTile(
            resena: resena,
            destacada: resena.esMia,
            onEditar: resena.esMia ? () => _editar(resena) : null,
            onEliminar: resena.esMia ? () => _eliminar(resena) : null,
          );
        },
      ),
    );
  }
}