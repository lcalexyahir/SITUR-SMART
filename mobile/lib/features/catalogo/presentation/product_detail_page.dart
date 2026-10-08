import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/product.dart';
import 'explore_page.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
  });

  final Product product;

  Widget _info(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.demoBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppTheme.accentDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final descripcion = (product.descripcion ?? '').trim();

    return Scaffold(
      appBar: AppBar(title: Text(product.tipo.nombre)),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ProductImage(product: product, height: 230),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.nombre,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.titleColor),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Desde ', style: TextStyle(color: AppTheme.textSecondary)),
                    Text(
                      product.precioTexto,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentDark,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                _info(Icons.place_outlined, 'Ubicación', product.ubicacion),
                _info(Icons.storefront_outlined, 'Ofrecido por', product.empresaNombre),
                _info(Icons.groups_outlined, 'Capacidad máxima', '${product.capacidadMaxima} personas'),
                _info(Icons.category_outlined, 'Tipo de experiencia', product.tipo.nombre),
                const Divider(height: 32),
                const Text('Descripción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  descripcion.isEmpty ? 'La empresa todavía no agregó una descripción.' : descripcion,
                  style: const TextStyle(fontSize: 15, height: 1.5, color: AppTheme.labelColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}