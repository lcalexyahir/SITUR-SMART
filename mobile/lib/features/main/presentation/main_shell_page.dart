import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/coming_soon_page.dart';
import '../../../shared/widgets/situr_app_bar.dart';
import '../../../shared/widgets/situr_bottom_nav.dart';
import '../../bitacora/presentation/bitacora_page.dart';
import '../../catalogo/presentation/explore_page.dart';
import '../../cliente/presentation/client_profile_page.dart';
import '../../dashboard/data/current_user_service.dart';
import '../../dashboard/models/current_user.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../roles/presentation/roles_page.dart';
import '../../tenants/presentation/tenants_list_page.dart';
import '../../usuarios/data/auth_service.dart';
import '../../usuarios/presentation/pages/users_page.dart';

/// Sección de la navegación principal (pestaña de la barra inferior).
class _Section {
  const _Section({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

/// Estructura principal de la app. Muestra secciones distintas según el
/// tipo de usuario:
/// - Cliente (viajero): Explorar, Mis viajes, Itinerarios, Favoritos,
///   Notificaciones y Mi perfil (igual que la web). Entra directo a Explorar.
/// - Personal y SuperAdmin: Inicio, Usuarios, Roles y Bitácora.
class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
  });

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  final CurrentUserService _userService = CurrentUserService();

  CurrentUser? _user;
  int _currentIndex = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _userService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } on AccessBlockedException {
      // ApiClient ya redirigió (acceso bloqueado o sesión expirada).
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) context.go('/login');
  }

  void _goTo(int index) => setState(() => _currentIndex = index);

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  // ---------------------------------------------------------------------------
  // Secciones del cliente (secciones sin módulo en el servidor: "Próximamente")
  // ---------------------------------------------------------------------------

  static const ComingSoonPage _itinerarios = ComingSoonPage(
    title: 'Itinerarios',
    icon: Icons.map_outlined,
    description: 'Organiza tus actividades y experiencias día por día.',
    standalone: true,
  );

  static const ComingSoonPage _notificaciones = ComingSoonPage(
    title: 'Notificaciones',
    icon: Icons.notifications_none,
    description: 'Confirmaciones de reserva, recordatorios y novedades de tus viajes.',
    standalone: true,
  );

  List<_Section> _sections(CurrentUser user) {
    if (user.isClient) {
      return [
        _Section(
          label: 'Explorar',
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore,
          page: ExplorePage(),
        ),
        _Section(
          label: 'Mis viajes',
          icon: Icons.luggage_outlined,
          selectedIcon: Icons.luggage,
          page: ComingSoonPage(
            title: 'Mis viajes',
            icon: Icons.luggage_outlined,
            description: 'Aquí verás tus reservas confirmadas, pendientes y realizadas.',
          ),
        ),
        _Section(
          label: 'Favoritos',
          icon: Icons.favorite_border,
          selectedIcon: Icons.favorite,
          page: ComingSoonPage(
            title: 'Favoritos',
            icon: Icons.favorite_border,
            description: 'Guarda las experiencias que te gustan para reservarlas después.',
          ),
        ),
        _Section(
          label: 'Mi perfil',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          page: ClientProfilePage(),
        ),
      ];
    }

    return [
      _Section(
        label: 'Inicio',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        page: DashboardPage(),
      ),
      _Section(
        label: 'Usuarios',
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        page: UsersPage(),
      ),
      _Section(
        label: 'Roles',
        icon: Icons.security_outlined,
        selectedIcon: Icons.security,
        page: RolesPage(),
      ),
      _Section(
        label: 'Bitácora',
        icon: Icons.history,
        selectedIcon: Icons.history,
        page: BitacoraPage(),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Menú lateral
  // ---------------------------------------------------------------------------

  List<DrawerEntry> _drawerEntries(CurrentUser user, List<_Section> sections) {
    DrawerEntry sectionEntry(int index) => DrawerEntry(
          label: sections[index].label,
          icon: sections[index].icon,
          selected: index == _currentIndex,
          onTap: () => _goTo(index),
        );

    if (user.isClient) {
      // Mismo orden que el menú del viajero en la web.
      return [
        sectionEntry(0), // Explorar
        sectionEntry(1), // Mis viajes
        DrawerEntry(
          label: 'Itinerarios',
          icon: Icons.map_outlined,
          onTap: () => _push(_itinerarios),
        ),
        sectionEntry(2), // Favoritos
        DrawerEntry(
          label: 'Notificaciones',
          icon: Icons.notifications_none,
          onTap: () => _push(_notificaciones),
        ),
        sectionEntry(3), // Mi perfil
      ];
    }

    final entries = <DrawerEntry>[
      for (var i = 0; i < sections.length; i++) sectionEntry(i),
    ];

    if (user.isSuperAdmin) {
      entries.insert(
        1,
        DrawerEntry(
          label: 'Empresas',
          icon: Icons.apartment,
          onTap: () => _push(const TenantsListPage()),
        ),
      );
    }

    entries.add(
      DrawerEntry(
        label: 'Mi perfil',
        icon: Icons.person_outline,
        onTap: () => _push(const ClientProfilePage(standalone: true)),
      ),
    );

    return entries;
  }

  // ---------------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _user == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? 'No se pudo cargar tu cuenta.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _loadUser, child: const Text('Reintentar')),
                  TextButton(onPressed: _logout, child: const Text('Volver al inicio de sesión')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final user = _user!;
    final sections = _sections(user);
    final index = _currentIndex < sections.length ? _currentIndex : 0;

    return Scaffold(
      appBar: const SiturAppBar(title: 'SITUR-SMART'),
      drawer: AppDrawer(
        user: user,
        entries: _drawerEntries(user, sections),
        onLogout: _logout,
      ),
      body: IndexedStack(
        index: index,
        children: sections.map((section) => section.page).toList(),
      ),
      bottomNavigationBar: SiturBottomNav(
        currentIndex: index,
        onTap: _goTo,
        items: sections
            .map(
              (section) => NavigationDestination(
                icon: Icon(section.icon),
                selectedIcon: Icon(section.selectedIcon),
                label: section.label,
              ),
            )
            .toList(),
      ),
    );
  }
}