import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/tenant_service.dart';
import '../models/tenant.dart';
import 'tenant_ui.dart';

class TenantEditPage extends StatefulWidget {
  const TenantEditPage({
    super.key,
    required this.tenant,
  });

  final Tenant tenant;

  @override
  State<TenantEditPage> createState() => _TenantEditPageState();
}

class _TenantEditPageState extends State<TenantEditPage> {
  final TenantService _service = TenantService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombre;
  late final TextEditingController _razon;
  late final TextEditingController _subdomain;
  late final TextEditingController _nit;
  late final TextEditingController _email;
  late final TextEditingController _telefono;

  bool _loading = false;

  static final RegExp _subdomainPattern = RegExp(r'^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$');
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    final tenant = widget.tenant;
    _nombre = TextEditingController(text: tenant.nombreComercial);
    _razon = TextEditingController(text: tenant.razonSocial);
    _subdomain = TextEditingController(text: tenant.subdomain);
    _nit = TextEditingController(text: tenant.nit ?? '');
    _email = TextEditingController(text: tenant.emailContacto ?? '');
    _telefono = TextEditingController(text: tenant.telefono ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _razon.dispose();
    _subdomain.dispose();
    _nit.dispose();
    _email.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      await _service.updateTenant(
        widget.tenant.id,
        {
          'nombre_comercial': _nombre.text.trim(),
          'razon_social': _razon.text.trim(),
          'subdomain': _subdomain.text.trim().toLowerCase(),
          'nit': _nit.text.trim(),
          'email_contacto': _email.text.trim(),
          'telefono': _telefono.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AccessBlockedException {
      // ApiClient ya redirigió a la pantalla de acceso bloqueado.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TenantUi.errorMessage(e)),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _required(String? value) {
    return (value == null || value.trim().isEmpty) ? 'Este campo es obligatorio.' : null;
  }

  Widget _campo({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar empresa')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _campo(label: 'Nombre comercial', controller: _nombre, validator: _required),
            _campo(label: 'Razón social', controller: _razon, validator: _required),
            _campo(
              label: 'Identificador web',
              controller: _subdomain,
              hint: 'ej. bodegas-kohlberg',
              validator: (value) {
                final text = (value ?? '').trim().toLowerCase();
                if (text.isEmpty) return 'Este campo es obligatorio.';
                if (!_subdomainPattern.hasMatch(text)) {
                  return 'Solo minúsculas, números y guiones (mínimo 3 caracteres).';
                }
                return null;
              },
            ),
            _campo(label: 'NIT (opcional)', controller: _nit, keyboardType: TextInputType.number),
            _campo(
              label: 'Correo de contacto (opcional)',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return null;
                return _emailPattern.hasMatch(text) ? null : 'Ingrese un correo válido.';
              },
            ),
            _campo(label: 'Teléfono (opcional)', controller: _telefono, keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _loading ? null : _guardar,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}