import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Pantalla para secciones que todavía no tienen módulo en el servidor.
/// [standalone] = true cuando se abre como pantalla aparte (con su AppBar).
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    this.standalone = false,
  });

  final String title;
  final IconData icon;
  final String description;
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.demoBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 48, color: AppTheme.accentDark),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.demoBorder),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Próximamente',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentDark),
              ),
            ),
          ],
        ),
      ),
    );

    if (!standalone) return body;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}