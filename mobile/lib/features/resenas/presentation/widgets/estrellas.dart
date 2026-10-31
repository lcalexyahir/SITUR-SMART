import 'package:flutter/material.dart';

/// Color de las estrellas en toda la app.
const Color colorEstrella = Color(0xFFF59E0B);

/// Muestra una calificación de 0 a 5 con medias estrellas.
class EstrellasCalificacion extends StatelessWidget {
  const EstrellasCalificacion({
    super.key,
    required this.valor,
    this.tamano = 16,
  });

  final double valor;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final posicion = index + 1;
        IconData icono;
        if (valor >= posicion) {
          icono = Icons.star_rounded;
        } else if (valor >= posicion - 0.5) {
          icono = Icons.star_half_rounded;
        } else {
          icono = Icons.star_outline_rounded;
        }
        return Icon(icono, size: tamano, color: colorEstrella);
      }),
    );
  }
}

/// Selector de 1 a 5 estrellas para el formulario de reseña.
class SelectorEstrellas extends StatelessWidget {
  const SelectorEstrellas({
    super.key,
    required this.valor,
    required this.onChanged,
    this.tamano = 40,
  });

  final int valor;
  final ValueChanged<int> onChanged;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final estrellas = index + 1;
        return Semantics(
          button: true,
          label: '$estrellas de 5 estrellas',
          selected: valor == estrellas,
          child: IconButton(
            onPressed: () => onChanged(estrellas),
            iconSize: tamano,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              valor >= estrellas ? Icons.star_rounded : Icons.star_outline_rounded,
              color: colorEstrella,
            ),
          ),
        );
      }),
    );
  }
}