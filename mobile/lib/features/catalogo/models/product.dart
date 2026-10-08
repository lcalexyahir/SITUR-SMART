class ProductType {
  final int id;
  final String codigo;
  final String nombre;

  ProductType({
    required this.id,
    required this.codigo,
    required this.nombre,
  });

  factory ProductType.fromJson(Map<String, dynamic> json) {
    return ProductType(
      id: json['id'] as int,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
    );
  }
}

/// Producto turístico publicado en el marketplace.
class Product {
  final int id;
  final String nombre;
  final String? descripcion;
  final String precio;
  final String moneda;
  final int capacidadMaxima;
  final String? imagenUrl;
  final String? localidad;
  final ProductType tipo;
  final String ciudad;
  final int empresaId;
  final String empresaNombre;

  Product({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.moneda,
    required this.capacidadMaxima,
    required this.imagenUrl,
    required this.localidad,
    required this.tipo,
    required this.ciudad,
    required this.empresaId,
    required this.empresaNombre,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final empresa = json['empresa'] as Map<String, dynamic>;
    return Product(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      precio: json['precio'].toString(),
      moneda: json['moneda'] as String,
      capacidadMaxima: json['capacidad_maxima'] as int,
      imagenUrl: json['imagen_url'] as String?,
      localidad: json['localidad'] as String?,
      tipo: ProductType.fromJson(json['tipo'] as Map<String, dynamic>),
      ciudad: json['ciudad'] as String,
      empresaId: empresa['id'] as int,
      empresaNombre: empresa['nombre'] as String,
    );
  }

  String get precioTexto => '$moneda $precio';

  String get ubicacion {
    final local = (localidad ?? '').trim();
    return local.isEmpty ? ciudad : '$local · $ciudad';
  }

  bool get tieneImagen => (imagenUrl ?? '').startsWith('http');
}