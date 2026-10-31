import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../../catalogo/presentation/product_detail_page.dart';
import '../data/resena_service.dart';
import '../models/resena.dart';
import 'resena_form_sheet.dart';
import 'widgets/estrellas.dart';

/// "Mis reseñas": calificaciones que el turista dejó, para editarlas o
/// eliminarlas sin buscar cada producto (CU35).
class MisResenasPage extends StatefulWidget {
  const MisResenasPage({super.key});

  @override
  State<MisResenasPage> createState() => _MisResenasPageState();
}

class _MisResenasPageState extends State<MisResenasPage> {
  final ResenaService _service = ResenaService();
  final ScrollController _scroll = ScrollController();
  final List<Resena> _resenas = [];
  final DateFormat _fecha = DateFormat('dd/MM/yyyy');

  int _pagina = 1;
  bool _haySiguiente = false;
  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _cargarMas();
    });
    _cargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await _service.getMisResenas();
      if (!mounted) return;
      setState(() {
        _resenas
          ..clear()
          ..addAll(datos.resultados);
        _pagina = 1;
        _haySiguiente = datos.haySiguiente;
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
      final datos = await _service.getMisResenas(page: _pagina + 1);
      if (!mounted) return;
      setState(() {
        _resenas.addAll(datos.resultados);
        _pagina++;
        _haySiguiente = datos.haySiguiente;
        _cargandoMas = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  Future<void> _editar(Resena resena) async {
    final guardado = await mostrarFormularioResena(
      context,
      productoId: resena.producto!.id,
      productoNombre: resena.producto!.nombre,
      resena: resena,
    );
    if (!guardado || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tu reseña se actualizó.')),
    );
    _cargar();
  }

  Future<void> _eliminar(Resena resena) async {
    if (await confirmarEliminarResena(context, resena)) _cargar();
  }

  Future<void> _abrirProducto(Resena resena) async {
    final producto = resena.producto!;
    if (!producto.disponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto ya no está publicado.')),
      );
      return;
    }
    try {
      final detalle = await _service.getProducto(producto.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailPage(product: detalle)),
      );
      if (mounted) _cargar();
    } on AccessBlockedException {
      // ApiClient ya redirigió.
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto no está disponible en este momento.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reseñas')),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _resenas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _resenas.isEmpty) {
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

    if (_resenas.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: const [
            SizedBox(height: 60),
            Icon(Icons.rate_review_outlined, size: 56, color: AppTheme.accentDark),
            SizedBox(height: 16),
            Text(
              'Todavía no calificaste ningún producto',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Abre un producto desde Explorar y toca "Calificar" para compartir tu experiencia.',
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
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _resenas.length + (_cargandoMas ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _resenas.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _tarjeta(_resenas[index]);
        },
      ),
    );
  }

  Widget _tarjeta(Resena resena) {
    final producto = resena.producto;
    if (producto == null) return const SizedBox.shrink();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrirProducto(resena),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.inputBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: producto.tieneImagen
                          ? Image.network(
                              producto.imagenUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const _ImagenRespaldo(),
                            )
                          : const _ImagenRespaldo(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producto.tipo.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentDark,
                          ),
                        ),
                        Text(
                          producto.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        if (!producto.disponible)
                          const Text(
                            'Ya no está publicado',
                            style: TextStyle(fontSize: 12, color: AppTheme.errorColor),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opciones de la reseña',
                    onSelected: (opcion) {
                      if (opcion == 'editar') _editar(resena);
                      if (opcion == 'eliminar') _eliminar(resena);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'editar',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'eliminar',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: AppTheme.errorColor),
                          title: Text('Eliminar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  EstrellasCalificacion(valor: resena.calificacion.toDouble()),
                  const SizedBox(width: 8),
                  Text(
                    '${etiquetasCalificacion[resena.calificacion] ?? ''} · ${_fecha.format(resena.creadoEn)}'
                    '${resena.editada ? ' · editada' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                resena.comentario,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.4, color: AppTheme.labelColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagenRespaldo extends StatelessWidget {
  const _ImagenRespaldo();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.demoBg,
      child: const Icon(Icons.landscape_outlined, color: AppTheme.accentDark),
    );
  }
}