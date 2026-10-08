import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/client_service.dart';
import '../models/client_profile.dart';

/// "Mi perfil". Para clientes incluye su documento (CI / Pasaporte).
/// [standalone] = true cuando se abre como pantalla aparte (con su AppBar).
class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({
    super.key,
    this.standalone = false,
  });

  final bool standalone;

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  final ClientService _service = ClientService();
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  final _numeroDocumento = TextEditingController();

  static const Map<String, String> _documentTypes = {
    'CI': 'Cédula de identidad (CI)',
    'PASAPORTE': 'Pasaporte',
  };

  ClientProfile? _profile;
  String? _tipoDocumento;
  DateTime? _fechaNacimiento;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _telefono.dispose();
    _numeroDocumento.dispose();
    super.dispose();
  }

  void _fill(ClientProfile profile) {
    _profile = profile;
    _nombres.text = profile.nombres;
    _apellidos.text = profile.apellidos;
    _telefono.text = profile.telefono ?? '';
    _numeroDocumento.text = profile.numeroDocumento ?? '';
    _tipoDocumento = _documentTypes.containsKey(profile.tipoDocumento) ? profile.tipoDocumento : null;
    _fechaNacimiento = profile.fechaNacimiento;
  }

  Future<void> _load() async {
    try {
      final profile = await _service.getProfile();
      if (!mounted) return;
      setState(() {
        _fill(profile);
        _error = null;
        _loading = false;
      });
    } on AccessBlockedException {
      // ApiClient ya redirigió a la pantalla de acceso bloqueado.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final profile = await _service.updateProfile(
        nombres: _nombres.text.trim(),
        apellidos: _apellidos.text.trim(),
        telefono: _telefono.text.trim(),
        tipoDocumento: _tipoDocumento,
        numeroDocumento: _numeroDocumento.text.trim(),
        fechaNacimiento: _fechaNacimiento,
      );
      if (!mounted) return;
      setState(() => _fill(profile));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tus datos se guardaron correctamente.')),
      );
    } on AccessBlockedException {
      // ApiClient ya redirigió a la pantalla de acceso bloqueado.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) {
      setState(() => _fechaNacimiento = picked);
    }
  }

  Future<void> _openChangePassword() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    if (!widget.standalone) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: body,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
        children: [
          const Text(
            'Mi perfil',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.titleColor),
          ),
          const SizedBox(height: 4),
          Text(profile.email, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          _card(
            title: 'Datos personales',
            children: [
              TextFormField(
                controller: _nombres,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombres'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tus nombres.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _apellidos,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Apellidos'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tus apellidos.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: profile.email,
                enabled: false,
                decoration: const InputDecoration(labelText: 'Correo electrónico'),
              ),
            ],
          ),
          if (profile.esCliente) ...[
            const SizedBox(height: 16),
            _card(
              title: 'Mis datos de viaje',
              subtitle: 'Se usarán en tus reservas.',
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _tipoDocumento,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tipo de documento'),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Sin especificar')),
                    ..._documentTypes.entries.map(
                      (entry) => DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _tipoDocumento = value),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _numeroDocumento,
                  decoration: const InputDecoration(labelText: 'Número de documento'),
                  validator: (v) {
                    final hasNumber = (v ?? '').trim().isNotEmpty;
                    if (hasNumber && _tipoDocumento == null) return 'Elige el tipo de documento.';
                    if (!hasNumber && _tipoDocumento != null) return 'Ingresa el número de documento.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickBirthDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha de nacimiento',
                      suffixIcon: _fechaNacimiento == null
                          ? const Icon(Icons.calendar_today_outlined)
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _fechaNacimiento = null),
                            ),
                    ),
                    child: Text(
                      _fechaNacimiento == null ? 'Sin especificar' : _dateFormat.format(_fechaNacimiento!),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar cambios'),
            ),
          ),
          const SizedBox(height: 20),
          _card(
            title: 'Seguridad y cuenta',
            subtitle: 'Cambia tu contraseña periódicamente para proteger tu cuenta.',
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openChangePassword,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Cambiar contraseña'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, String? subtitle, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Hoja inferior para cambiar la contraseña.
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final ClientService _service = ClientService();
  final _formKey = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();

  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.changePassword(actual: _actual.text, nueva: _nueva.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AccessBlockedException {
      // ApiClient ya redirigió a la pantalla de acceso bloqueado.
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cambiar contraseña',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _actual,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña actual.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nueva,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa la nueva contraseña.';
                if (v.length < 8) return 'Debe tener al menos 8 caracteres.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmar,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Confirmar nueva contraseña'),
              validator: (v) => v != _nueva.text ? 'Las contraseñas no coinciden.' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Actualizar contraseña'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}