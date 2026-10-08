import 'package:go_router/go_router.dart';

import '../../features/main/presentation/main_shell_page.dart';
import '../../features/suscripciones/presentation/subscription_inactive_page.dart';
import '../../features/usuarios/presentation/pages/forgot_password_page.dart';
import '../../features/usuarios/presentation/pages/login_page.dart';
import '../../features/usuarios/presentation/pages/register_page.dart';
import '../../features/usuarios/presentation/pages/splash_page.dart';
import '../../features/usuarios/presentation/pages/users_page.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'inicio',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/registrar-usuario',
        name: 'registrar-usuario',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/recuperar-password',
        name: 'recuperar-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const MainShellPage(),
      ),
      GoRoute(
        path: '/users',
        name: 'users',
        builder: (context, state) => const UsersPage(),
      ),
      GoRoute(
        path: '/acceso-bloqueado',
        name: 'acceso-bloqueado',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map) {
            return SubscriptionInactivePage(
              title: extra['titulo'] as String?,
              message: extra['mensaje'] as String?,
            );
          }
          return const SubscriptionInactivePage();
        },
      ),
    ],
  );
}