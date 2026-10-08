import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/catalog_service.dart';
import '../models/product.dart';
import 'product_detail_page.dart';

/// Explorar: catálogo de experiencias publicadas por las empresas.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final CatalogService _service = CatalogService();
  final TextEditingController _search = TextEditingController();

  List<ProductType> _types = [];
  List<Product> _products = [];
  int? _typeId;
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadTypes();
    _loadProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    try {
      final types = await _service.getTypes();
      if (mounted) setState(() => _types = types);
    } catch (_) {
      // Sin tipos se puede seguir explorando con el buscador.
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _service.getProducts(query: _search.text, typeId: _typeId);
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } on AccessBlockedException {
      // ApiClient ya redirigió a la pantalla de acceso bloqueado.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _loadProducts);
    setState(() {});
  }

  void _selectType(int? typeId) {
    setState(() => _typeId = typeId);
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: TextField(
            controller: _search,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadProducts(),
            decoration: InputDecoration(
              hintText: 'Buscar destinos, tours, hoteles…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _loadProducts();
                      },
                    ),
            ),
          ),
        ),
        if (_types.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: const Text('Todos'),
                    selected: _typeId == null,
                    onSelected: (_) => _selectType(null),
                  ),
                ),
                ..._types.map(
                  (type) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(type.nombre),
                      selected: _typeId == type.id,
                      onSelected: (_) => _selectType(type.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _loadProducts, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: _products.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 60),
                Icon(Icons.travel_explore, size: 56, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Text(
                  'No encontramos experiencias con esos filtros.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, index) => _ProductCard(product: _products[index]),
            ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.inputBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductImage(product: product, height: 160),
              Padding(
                padding: const EdgeInsets.all(14),
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
                    const SizedBox(height: 4),
                    Text(
                      product.nombre,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.ubicacion,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.empresaNombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ),
                        Text(
                          product.precioTexto,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.titleColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Imagen del producto con un fondo de respaldo si no hay imagen o falla.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.product,
    required this.height,
  });

  final Product product;
  final double height;

  Widget _placeholder() {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accentDark, AppTheme.panelBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.landscape_outlined, color: Colors.white70, size: 48),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!product.tieneImagen) return _placeholder();
    return Image.network(
      product.imagenUrl!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : SizedBox(
              height: height,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
    );
  }
}