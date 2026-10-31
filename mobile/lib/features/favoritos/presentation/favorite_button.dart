import 'package:flutter/material.dart';

import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/favorito_service.dart';

/// Corazón para marcar o quitar un producto de favoritos.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.productoId,
    this.color = AppTheme.errorColor,
    this.colorInactivo,
  });

  final int productoId;
  final Color color;
  final Color? colorInactivo;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final FavoritoService _service = FavoritoService();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _service.cargarIds().catchError((_) {});
  }

  Future<void> _alternar(bool marcado) async {
    setState(() => _guardando = true);
    try {
      if (marcado) {
        await _service.quitar(widget.productoId);
      } else {
        await _service.marcar(widget.productoId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(marcado ? 'Se quitó de tus favoritos.' : 'Se agregó a tus favoritos.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: FavoritoService.ids,
      builder: (context, ids, _) {
        final marcado = ids.contains(widget.productoId);
        return IconButton(
          tooltip: marcado ? 'Quitar de favoritos' : 'Agregar a favoritos',
          onPressed: _guardando ? null : () => _alternar(marcado),
          icon: Icon(
            marcado ? Icons.favorite : Icons.favorite_border,
            color: marcado ? widget.color : (widget.colorInactivo ?? IconTheme.of(context).color),
          ),
        );
      },
    );
  }
}