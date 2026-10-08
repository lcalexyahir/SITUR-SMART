import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_errors.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/auth_service.dart';


/// Pantalla de autenticación de usuarios.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}


/// Controla el formulario, validaciones y proceso de login.
class _LoginPageState extends State<LoginPage> {

  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();

  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _obscurePassword = true;

  bool _isLoading = false;

  String? _errorMessage;


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  /// Realiza autenticación y guarda la sesión del usuario.
  /// La sesión queda guardada hasta que el usuario cierre sesión.
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

      final response = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );


      final storage = TokenStorage();


      await storage.saveTokens(
        access: response['access'],
        refresh: response['refresh'],
      );


      await storage.saveUser(
        response['user'],
      );


      if (!mounted) {
        return;
      }


      context.go('/dashboard');


    } catch (e) {

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = apiErrorMessage(e);
      });


    } finally {

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

    }
  }


  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    return Scaffold(

      backgroundColor: Colors.white,

      body: SafeArea(

        child: Center(

          child: SingleChildScrollView(

            padding: const EdgeInsets.all(28),

            child: Form(

              key: _formKey,

              child: Column(

                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  const _MobileLogo(),

                  const SizedBox(height: 40),


                  Text(
                    'Bienvenido de vuelta',
                    style: theme.textTheme.headlineMedium,
                  ),


                  const SizedBox(height: 10),


                  Text(
                    'Ingresa tus credenciales para continuar',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),


                  const SizedBox(height: 30),


                  if (_errorMessage != null)
                    _ErrorMessage(
                      message: _errorMessage!,
                    ),


                  TextFormField(

                    controller: _emailController,

                    keyboardType: TextInputType.emailAddress,

                    autocorrect: false,

                    textInputAction: TextInputAction.next,

                    decoration:
                        const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon:
                          Icon(Icons.email_outlined),
                    ),

                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'El correo es obligatorio.';
                      }

                      return null;
                    },
                  ),


                  const SizedBox(height: 20),


                  TextFormField(

                    controller: _passwordController,

                    obscureText: _obscurePassword,

                    textInputAction: TextInputAction.done,

                    onFieldSubmitted: (_) {
                      if (!_isLoading) {
                        _submit();
                      }
                    },

                    decoration: InputDecoration(

                      labelText: 'Contraseña',

                      prefixIcon:
                          const Icon(Icons.lock_outline),

                      suffixIcon:
                          IconButton(

                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),

                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                                !_obscurePassword;
                          });
                        },

                      ),
                    ),

                    validator: (value) {

                      if (value == null ||
                          value.isEmpty) {

                        return 'La contraseña es obligatoria.';
                      }

                      return null;
                    },
                  ),


                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => context.push('/recuperar-password'),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                      ),
                    ),
                  ),


                  const SizedBox(height: 16),


                  SizedBox(

                    width: double.infinity,

                    height: 52,

                    child: ElevatedButton(

                      onPressed:
                          _isLoading
                              ? null
                              : _submit,

                      child:
                          _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Iniciar sesión',
                                ),
                    ),
                  ),


                  const SizedBox(height: 24),


                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          '¿No tienes una cuenta?',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => context.push('/registrar-usuario'),
                          child: const Text(
                            'Crear cuenta',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Muestra el logo principal del sistema.
class _MobileLogo extends StatelessWidget {

  const _MobileLogo();


  @override
  Widget build(BuildContext context) {

    return Row(

      children: [

        Container(

          width: 50,

          height: 50,

          decoration: BoxDecoration(

            color: AppTheme.accent,

            borderRadius:
                BorderRadius.circular(14),

          ),

          child: const Icon(
            Icons.travel_explore,
            color: Colors.white,
          ),
        ),


        const SizedBox(width: 12),


        const Text(
          'SITUR-SMART',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

      ],
    );
  }
}


/// Muestra errores del proceso de autenticación.
class _ErrorMessage extends StatelessWidget {

  final String message;


  const _ErrorMessage({
    required this.message,
  });


  @override
  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 16),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(

        children: [

          const Icon(
            Icons.error_outline,
            color: AppTheme.errorColor,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.errorColor,
              ),
            ),
          ),

        ],
      ),
    );
  }
}