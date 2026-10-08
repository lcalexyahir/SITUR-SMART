import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/usuarios/data/auth_service.dart';

class SiturAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const SiturAppBar({
    super.key,
    required this.title,
  });

  Future<void> _logout(BuildContext context) async {
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