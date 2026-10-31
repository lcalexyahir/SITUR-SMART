import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/resena.dart';
import 'estrellas.dart';

/// Tarjeta de una reseña. Si es propia y se pasan [onEditar] y [onEliminar],
/// muestra el menú para gestionarla.
class ResenaTile extends StatelessWidget {
  const ResenaTile({
    super.key,
    required this.resena,
    this.onEditar,
    this.onEliminar,
    this.destacada = false,
  });

  final Resena resena;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  /// Fondo resaltado para "Tu reseña".
  final bool destacada;

  static final DateFormat _fecha = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final gestionable = onEditar != null || onEliminar != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: destacada ? AppTheme.demoBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: destacada ? AppTheme.demoBorder : AppTheme.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.accentDark,
                child: Text(
                  resena.iniciales,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resena.esMia ? 'Tú' : resena.autor,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        EstrellasCalificacion(valor: resena.calificacion.toDouble(), tamano: 15),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${_fecha.format(resena.creadoEn)}${resena.editada ? ' · editada' : ''}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (gestionable)
                PopupMenuButton<String>(
                  tooltip: 'Opciones de la reseña',
                  icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                  onSelected: (opcion) {
                    if (opcion == 'editar') onEditar?.call();
                    if (opcion == 'eliminar') onEliminar?.call();
                  },
                  itemBuilder: (context) => [
                    if (onEditar != null)
                      const PopupMenuItem(
                        value: 'editar',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (onEliminar != null)
                      const PopupMenuItem(
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
          Text(
            resena.comentario,
            style: const TextStyle(fontSize: 14, height: 1.45, color: AppTheme.labelColor),
          ),
        ],
      ),
    );
  }
}

/// Resumen con el promedio grande y una barra por cada cantidad de estrellas.
class ResumenResenasCard extends StatelessWidget {
  const ResumenResenasCard({super.key, required this.resumen});

  final ResumenResenas resumen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.inputBorder),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                resumen.promedioTexto,
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppTheme.titleColor),
              ),
              EstrellasCalificacion(valor: resumen.promedio ?? 0, tamano: 16),
              const SizedBox(height: 4),
              Text(
                resumen.total == 1 ? '1 reseña' : '${resumen.total} reseñas',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                for (var estrellas = 5; estrellas >= 1; estrellas--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          child: Text('$estrellas', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ),
                        const Icon(Icons.star_rounded, size: 12, color: colorEstrella),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: resumen.porcentaje(estrellas),
                              minHeight: 7,
                              backgroundColor: AppTheme.inputBorder,
                              color: colorEstrella,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${resumen.distribucion[estrellas] ?? 0}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}