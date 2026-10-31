import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../../catalogo/models/product.dart';
import '../../catalogo/presentation/explore_page.dart';
import '../../catalogo/presentation/product_detail_page.dart';
import '../data/favorito_service.dart';
import 'favorite_button.dart';

/// Productos que el turista guardó. Es una pestaña de la barra inferior.
class FavoritosPage extends StatefulWidget {
  const FavoritosPage({super.key});

  @override
  State<FavoritosPage> createState() => _FavoritosPageState();
}

class _FavoritosPageState extends State<FavoritosPage> {
  final FavoritoService _service = FavoritoService();

  List<Product> _productos = [];
  bool _cargando = true;
  bool _recargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    FavoritoService.ids.addListener(_alCambiarIds);
    _cargar();
  }

  @override
  void dispose() {
    FavoritoService.ids.removeListener(_alCambiarIds);
    super.dispose();
  }

  /// Si se marca o quita un favorito en otra pantalla, la lista se actualiza.
  void _alCambiarIds() {
    if (!mounted || _cargando || _recargando) return;
    final ids = FavoritoService.ids.value;
    final mostrados = _productos.map((p) => p.id).toSet();
    if (mostrados.difference(ids).isNotEmpty || ids.difference(mostrados).isNotEmpty) {
      _cargar(silencioso: true);
    }
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    _recargando = true;
    try {
      final productos = await _service.getFavoritos();
      if (!mounted) return;
      setState(() {
        _productos = productos;
        _cargando = false;
        _error = null;
      });
    } on AccessBlockedException {
      // ApiClient ya redirigió.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _cargando = false;
      });
    } finally {
      _recargando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando && _productos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _productos.isEmpty) {
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

    if (_productos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: const [
            SizedBox(height: 60),
            Icon(Icons.favorite_border, size: 56, color: AppTheme.accentDark),
            SizedBox(height: 16),
            Text(
              'Todavía no tienes favoritos',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Toca el corazón en la ficha de un producto para guardarlo aquí.',
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
        padding: const EdgeInsets.all(16),
        itemCount: _productos.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(
              _productos.length == 1 ? '1 producto guardado' : '${_productos.length} productos guardados',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.titleColor),
            );
          }
          return _TarjetaFavorito(product: _productos[index - 1]);
        },
      ),
    );
  }
}

class _TarjetaFavorito extends StatelessWidget {
  const _TarjetaFavorito({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.inputBorder),
          ),
          child: Row(
            children: [
              SizedBox(width: 110, height: 110, child: ProductImage(product: product, height: 110)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.tipo.nombre.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.ubicacion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.precioTexto,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.titleColor),
                      ),
                    ],
                  ),
                ),
              ),
              FavoriteButton(productoId: product.id),
            ],
          ),
        ),
      ),
    );
  }
}