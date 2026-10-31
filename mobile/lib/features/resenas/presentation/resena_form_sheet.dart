import 'package:flutter/material.dart';

import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/resena_service.dart';
import '../models/resena.dart';
import 'widgets/estrellas.dart';

/// Abre el formulario para calificar un producto o editar la reseña propia.
/// Devuelve true si se guardó.
Future<bool> mostrarFormularioResena(
  BuildContext context, {
  required int productoId,
  required String productoNombre,
  Resena? resena,
}) async {
  final guardado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ResenaFormSheet(
      productoId: productoId,
      productoNombre: productoNombre,
      resena: resena,
    ),
  );
  return guardado ?? false;
}

class _ResenaFormSheet extends StatefulWidget {
  const _ResenaFormSheet({
    required this.productoId,
    required this.productoNombre,
    this.resena,
  });

  final int productoId;
  final String productoNombre;
  final Resena? resena;

  @override
  State<_ResenaFormSheet> createState() => _ResenaFormSheetState();
}

class _ResenaFormSheetState extends State<_ResenaFormSheet> {
  static const int _minimo = 3;
  static const int _maximo = 1000;

  final ResenaService _service = ResenaService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _comentario;

  int _calificacion = 0;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.resena != null;

  @override
  void initState() {
    super.initState();
    _calificacion = widget.resena?.calificacion ?? 0;
    _comentario = TextEditingController(text: widget.resena?.comentario ?? '');
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_calificacion == 0) {
      setState(() => _error = 'Elige una calificación de 1 a 5 estrellas.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_editando) {
        await _service.editarResena(
          resenaId: widget.resena!.id,
          calificacion: _calificacion,
          comentario: _comentario.text,
        );
      } else {
        await _service.crearResena(
          productoId: widget.productoId,
          calificacion: _calificacion,
          comentario: _comentario.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = apiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + teclado),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _editando ? 'Editar tu reseña' : '¿Qué te pareció?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.titleColor),
              ),
              const SizedBox(height: 4),
              Text(
                widget.productoNombre,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              SelectorEstrellas(
                valor: _calificacion,
                onChanged: _guardando
                    ? (_) {}
                    : (valor) => setState(() {
                          _calificacion = valor;
                          _error = null;
                        }),
              ),
              SizedBox(
                height: 22,
                child: Text(
                  etiquetasCalificacion[_calificacion] ?? 'Toca las estrellas para calificar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: _calificacion == 0 ? FontWeight.normal : FontWeight.w700,
                    color: _calificacion == 0 ? AppTheme.textSecondary : AppTheme.accentDark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _comentario,
                enabled: !_guardando,
                minLines: 4,
                maxLines: 8,
                maxLength: _maximo,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tu comentario',
                  hintText: 'Cuéntales a otros viajeros cómo fue tu experiencia',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final texto = (value ?? '').trim();
                  if (texto.isEmpty) return 'Escribe un comentario sobre tu experiencia.';
                  if (texto.length < _minimo) {
                    return 'El comentario debe tener al menos $_minimo caracteres.';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_editando ? 'Guardar cambios' : 'Publicar reseña'),
              ),
              TextButton(
                onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pide confirmación y elimina la reseña. Devuelve true si se eliminó.
Future<bool> confirmarEliminarResena(BuildContext context, Resena resena) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Eliminar reseña'),
      content: const Text('Tu calificación y tu comentario dejarán de verse en este producto. ¿Deseas continuar?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (confirmar != true || !context.mounted) return false;

  try {
    await ResenaService().eliminarResena(resena.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu reseña se eliminó.')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: AppTheme.errorColor),
      );
    }
    return false;
  }
}