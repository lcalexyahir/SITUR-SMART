import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/resena_service.dart';
import '../models/resena.dart';
import 'product_reviews_page.dart';
import 'resena_form_sheet.dart';
import 'widgets/resena_tile.dart';

/// Bloque "Calificaciones y reseñas" de la ficha del producto (CU35).
class ProductReviewsSection extends StatefulWidget {
  const ProductReviewsSection({
    super.key,
    required this.productoId,
    required this.productoNombre,
  });

  final int productoId;
  final String productoNombre;

  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  static const int _vistaPrevia = 3;

  final ResenaService _service = ResenaService();

  PaginaResenas? _pagina;
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
      // Se pide una más por si una de ellas es la propia (se muestra aparte).
      final pagina = await _service.getResenasProducto(widget.productoId, pageSize: _vistaPrevia + 1);
      if (!mounted) return;
      setState(() {
        _pagina = pagina;
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

  Future<void> _calificar({Resena? resena}) async {
    final guardado = await mostrarFormularioResena(
      context,
      productoId: widget.productoId,
      productoNombre: widget.productoNombre,
      resena: resena,
    );
    if (!guardado || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resena == null ? '¡Gracias! Tu reseña se publicó.' : 'Tu reseña se actualizó.')),
    );
    _cargar();
  }

  Future<void> _eliminar(Resena resena) async {
    if (await confirmarEliminarResena(context, resena)) _cargar();
  }

  Future<void> _verTodas() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductReviewsPage(
          productoId: widget.productoId,
          productoNombre: widget.productoNombre,
        ),
      ),
    );
    // Pudo editar o eliminar su reseña desde la lista completa.
    if (mounted) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Calificaciones y reseñas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _contenido(),
      ],
    );
  }

  Widget _contenido() {
    if (_cargando && _pagina == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _pagina == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
          TextButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
        ],
      );
    }

    final pagina = _pagina!;
    final mia = pagina.miResena;
    final otras = pagina.resultados.where((r) => !r.esMia).take(_vistaPrevia).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pagina.resumen.total > 0) ...[
          ResumenResenasCard(resumen: pagina.resumen),
          const SizedBox(height: 12),
        ],
        if (mia != null) ...[
          const Text('Tu reseña', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.labelColor)),
          const SizedBox(height: 6),
          ResenaTile(
            resena: mia,
            destacada: true,
            onEditar: () => _calificar(resena: mia),
            onEliminar: () => _eliminar(mia),
          ),
          const SizedBox(height: 12),
        ] else if (pagina.puedeResenar) ...[
          _InvitacionCalificar(onPressed: () => _calificar()),
          const SizedBox(height: 12),
        ],
        if (pagina.resumen.total == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Este producto todavía no tiene reseñas.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        for (final resena in otras) ...[
          ResenaTile(resena: resena),
          const SizedBox(height: 10),
        ],
        if (pagina.resumen.total > otras.length + (mia == null ? 0 : 1))
          OutlinedButton(
            onPressed: _verTodas,
            child: Text('Ver las ${pagina.resumen.total} reseñas'),
          ),
      ],
    );
  }
}

class _InvitacionCalificar extends StatelessWidget {
  const _InvitacionCalificar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.demoBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.demoBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.rate_review_outlined, color: AppTheme.accentDark),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '¿Ya viviste esta experiencia? Ayuda a otros viajeros con tu opinión.',
              style: TextStyle(color: AppTheme.labelColor),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onPressed, child: const Text('Calificar')),
        ],
      ),
    );
  }
}