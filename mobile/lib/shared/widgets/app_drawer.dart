import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/dashboard/models/current_user.dart';

/// Opción del menú lateral.
class DrawerEntry {
  const DrawerEntry({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
}

/// Menú lateral de SITUR-SMART. Sus opciones dependen del tipo de usuario.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.user,
    required this.entries,
    required this.onLogout,
  });

  final CurrentUser user;
  final List<DrawerEntry> entries;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.panelBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              child: Row(
                children: [
                  const Icon(Icons.travel_explore, color: AppTheme.accent, size: 28),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'SITUR-SMART',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: entries
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: entry.selected ? Colors.white.withValues(alpha: 0.12) : null,
                          leading: Icon(entry.icon, color: Colors.white),
                          title: Text(
                            entry.label,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: entry.selected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            entry.onTap();
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.accent,
                    child: Text(
                      user.iniciales,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nombreCompleto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user.rolPrincipal,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    icon: const Icon(Icons.logout, color: Colors.white70),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onLogout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}