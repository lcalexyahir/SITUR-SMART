import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/favoritos/data/favorito_service.dart';
import '../../features/notificaciones/data/notificacion_service.dart';
import '../../features/usuarios/data/auth_service.dart';

class SiturAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// Botones extra antes de "Cerrar sesión" (por ejemplo, la campana).
  final List<Widget> actions;

  const SiturAppBar({
    super.key,
    required this.title,
    this.actions = const [],
  });

  Future<void> _logout(BuildContext context) async {
    // La campana de la próxima cuenta no debe mostrar el contador de esta.
    NotificacionService.noLeidas.value = 0;
    FavoritoService.limpiar();
    await AuthService().logout();
    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.accentDark,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        ...actions,
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(
            Icons.logout,
          ),
          onPressed: () => _logout(context),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}