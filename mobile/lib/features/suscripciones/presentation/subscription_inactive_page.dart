import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Pantalla que se muestra cuando el servidor bloquea el acceso:
/// suscripción no vigente o empresa no habilitada.
class SubscriptionInactivePage extends StatelessWidget {
  const SubscriptionInactivePage({
    super.key,
    this.title,
    this.message,
  });

  final String? title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_clock_outlined,
                  size: 72,
                  color: AppTheme.accentDark,
                ),
                const SizedBox(height: 20),
                Text(
                  title ?? 'Acceso no disponible',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.titleColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message ??
                      'Su empresa no puede usar el sistema en este momento. '
                          'Contacte al administrador del sistema.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Volver al inicio de sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}