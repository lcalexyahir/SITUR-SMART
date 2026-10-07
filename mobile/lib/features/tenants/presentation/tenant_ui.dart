import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Utilidades visuales compartidas por las pantallas de empresas.
class TenantUi {
  TenantUi._();

  static const Color green = Color(0xFF16A34A);
  static const Color amber = Color(0xFFD97706);
  static const Color blueGrey = Color(0xFF475569);

  static String statusLabel(String estado) {
    switch (estado) {
      case 'ACTIVO':
        return 'Activa';
      case 'PENDIENTE':
        return 'Pendiente';
      case 'SUSPENDIDO':
        return 'Suspendida';
      case 'INACTIVO':
        return 'Inactiva';
      default:
        return estado;
    }
  }

  static Color statusColor(String estado) {
    switch (estado) {
      case 'ACTIVO':
        return green;
      case 'PENDIENTE':
        return amber;
      case 'SUSPENDIDO':
        return AppTheme.errorColor;
      default:
        return blueGrey;
    }
  }

  static Color subscriptionColor(String? estado) {
    switch (estado) {
      case 'ACTIVA':
        return green;
      case 'VENCIDA':
        return amber;
      case 'SUSPENDIDA':
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  static Widget chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  static Widget statusChip(String estado) => chip(statusLabel(estado), statusColor(estado));

  static Widget avatar(String iniciales, {double size = 46}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        iniciales,
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.titleColor),
      ),
    );
  }

  /// Convierte el error del servidor en un mensaje legible.
  static String errorMessage(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is Map<String, dynamic>) {
          final details = err['details'];
          if (details is Map<String, dynamic>) {
            for (final entry in details.entries) {
              if (entry.key == 'code') continue;
              final value = entry.value;
              if (value is List && value.isNotEmpty) return value.first.toString();
              if (value is String) return value;
            }
          }
          if (err['message'] is String) return err['message'] as String;
        }
      }
    } catch (_) {
      // No es JSON: se devuelve el texto original.
    }
    return raw;
  }
}