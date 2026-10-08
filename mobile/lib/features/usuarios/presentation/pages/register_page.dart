import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_errors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';

/// Registro público de clientes (viajeros / turistas).
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.registerClient(
        nombres: _nombresController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        email: _emailController.text.trim(),
        telefono: _telefonoController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Bienvenido a SITUR-SMART! Tu cuenta fue creada.')),
      );
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _required(String? value, String field) {
    if (value == null || value.trim().isEmpty) return 'Ingresa tu $field.';
    return null;
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.labelColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isLoading ? null : () => context.go('/login'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Volver al inicio de sesión'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.travel_explore, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'SITUR-SMART',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.titleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Crea tu cuenta de viajero',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: AppTheme.titleColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Explora y reserva experiencias turísticas en toda Bolivia.',
                style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.errorColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _label('Nombres'),
              TextFormField(
                controller: _nombresController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Juan Carlos',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => _required(value, 'nombre'),
              ),
              const SizedBox(height: 16),
              _label('Apellidos'),
              TextFormField(
                controller: _apellidosController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'García López',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => _required(value, 'apellido'),
              ),
              const SizedBox(height: 16),
              _label('Correo electrónico'),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'juan@ejemplo.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Ingresa tu correo.';
                  if (!_emailPattern.hasMatch(text)) return 'Ingresa un correo válido.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _label('Teléfono (opcional)'),
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '70000000',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              _label('Contraseña'),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Mínimo 8 caracteres',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa una contraseña.';
                  if (value.length < 8) return 'Debe tener al menos 8 caracteres.';
                  if (RegExp(r'^\d+$').hasMatch(value)) return 'No puede ser solo números.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _label('Confirmar contraseña'),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                decoration: InputDecoration(
                  hintText: 'Repite tu contraseña',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Confirma tu contraseña.';
                  if (value != _passwordController.text) return 'Las contraseñas no coinciden.';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Crear cuenta'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : () => context.go('/login'),
                  child: const Text('¿Ya tienes cuenta? Inicia sesión'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}