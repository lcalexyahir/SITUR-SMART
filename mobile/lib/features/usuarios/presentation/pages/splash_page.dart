import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';

/// Pantalla de inicio: si hay una sesión guardada entra directo;
/// si no, muestra el login.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    var hasSession = false;
    try {
      hasSession = await AuthService().restoreSession();
    } on AccessBlockedException {
      // ApiClient ya redirigió a la pantalla de acceso bloqueado.
      return;
    } catch (_) {
      hasSession = false;
    }

    if (!mounted) return;
    context.go(hasSession ? '/dashboard' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.travel_explore, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'SITUR-SMART',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.titleColor,
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}