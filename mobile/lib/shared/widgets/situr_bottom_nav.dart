import 'package:flutter/material.dart';

class SiturBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  /// Opciones de la barra. Si no se indican, se usan las del personal
  /// (Inicio, Usuarios, Roles y Bitácora).
  final List<NavigationDestination>? items;

  const SiturBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items,
  });

  static const List<NavigationDestination> _defaultItems = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Inicio',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'Usuarios',
    ),
    NavigationDestination(
      icon: Icon(Icons.security_outlined),
      selectedIcon: Icon(Icons.security),
      label: 'Roles',
    ),
    NavigationDestination(
      icon: Icon(Icons.history),
      label: 'Bitácora',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: items ?? _defaultItems,
    );
  }
}