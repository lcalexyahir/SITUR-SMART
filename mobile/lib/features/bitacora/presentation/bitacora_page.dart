import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/bitacora_service.dart';
import '../models/bitacora.dart';

/// Bitácora confidencial.
///
/// Primero pide la llave del desarrollador; con ella consulta el archivo
/// cifrado del servidor. La llave se guarda solo en memoria y se borra al
/// bloquear o salir de la pantalla. Fechas y horas en hora de Bolivia.
class BitacoraPage extends StatefulWidget {
  const BitacoraPage({
    super.key,
  });

  @override
  State<BitacoraPage> createState() => _BitacoraPageState();
}

class _BitacoraPageState extends State<BitacoraPage> {
  final BitacoraService _service = BitacoraService();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  final _llaveController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _accionController = TextEditingController();
  final _ipController = TextEditingController();

  String? _llave;
  bool _ocultarLlave = true;
  DateTime? _desde;
  DateTime? _hasta;

  BitacoraResultado? _resultado;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _llaveController.dispose();
    _usuarioController.dispose();
    _accionController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------------

  Future<void> _desbloquear() async {
    final llave = _llaveController.text;
    if (llave.trim().isEmpty) {
      setState(() => _error = 'Ingresa la llave del desarrollador.');
      return;
    }
    FocusScope.of(context).unfocus();
    await _consultar(llave: llave);
  }

  Future<void> _consultar({String? llave}) async {
    final key = llave ?? _llave;
    if (key == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resultado = await _service.consultar(
        llave: key,
        desde: _desde,
        hasta: _hasta,
        usuario: _usuarioController.text,
        accion: _accionController.text,
        ip: _ipController.text,
      );
      if (!mounted) return;
      setState(() {
        _llave = key;
        _llaveController.clear();
        _resultado = resultado;
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

  void _bloquear() {
    setState(() {
      _llave = null;
      _resultado = null;
      _error = null;
      _llaveController.clear();
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _desde = null;
      _hasta = null;
      _usuarioController.clear();
      _accionController.clear();
      _ipController.clear();
    });
    _consultar();
  }

  Future<void> _elegirFecha({required bool esDesde}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (esDesde ? _desde : _hasta) ?? now,
      firstDate: DateTime(2024),
      lastDate: now,
      helpText: esDesde ? 'Desde' : 'Hasta',
    );
    if (picked == null) return;
    setState(() {
      if (esDesde) {
        _desde = picked;
      } else {
        _hasta = picked;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return _llave == null ? _pantallaBloqueada() : _pantallaRegistros();
  }

  Widget _pantallaBloqueada() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.demoBg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.lock_outline, size: 44, color: AppTheme.accentDark),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Bitácora confidencial',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.titleColor),
            ),
            const SizedBox(height: 8),
            const Text(
              'Registro cifrado de todas las acciones de los usuarios: IP, usuario, fecha, hora y acción. '
              'Solo puede consultarse con la llave única del desarrollador.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              _errorBox(_error!),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _llaveController,
              obscureText: _ocultarLlave,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _loading ? null : _desbloquear(),
              decoration: InputDecoration(
                labelText: 'Llave del desarrollador',
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_ocultarLlave ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _ocultarLlave = !_ocultarLlave),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _desbloquear,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.lock_open),
                label: const Text('Desbloquear bitácora'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pantallaRegistros() {
    final resultado = _resultado;

    return RefreshIndicator(
      onRefresh: () => _consultar(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bitácora',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.titleColor),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _bloquear,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Bloquear'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Hora de Bolivia · ${resultado?.zonaHoraria ?? 'America/La_Paz (UTC-04:00)'}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _filtros(),
          const SizedBox(height: 16),
          if (_error != null) ...[
            _errorBox(_error!),
            const SizedBox(height: 12),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (resultado != null) ...[
            Text(
              resultado.total == resultado.mostrando
                  ? '${resultado.total} registros'
                  : 'Mostrando los ${resultado.mostrando} más recientes de ${resultado.total}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.labelColor),
            ),
            const SizedBox(height: 10),
            if (resultado.registros.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No hay registros con esos filtros.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ...resultado.registros.map(_registroCard),
          ],
        ],
      ),
    );
  }

  Widget _filtros() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _fechaBox('Desde', _desde, () => _elegirFecha(esDesde: true), () {
                setState(() => _desde = null);
              })),
              const SizedBox(width: 10),
              Expanded(child: _fechaBox('Hasta', _hasta, () => _elegirFecha(esDesde: false), () {
                setState(() => _hasta = null);
              })),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usuarioController,
            decoration: const InputDecoration(
              labelText: 'Usuario (nombre o correo)',
              prefixIcon: Icon(Icons.person_search_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accionController,
            decoration: const InputDecoration(
              labelText: 'Acción (ej. "sesión", "empresa")',
              prefixIcon: Icon(Icons.manage_search),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ipController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'IP',
              prefixIcon: Icon(Icons.router_outlined),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : () => _consultar(),
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('Aplicar filtros'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _loading ? null : _limpiarFiltros,
                child: const Text('Limpiar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fechaBox(String label, DateTime? value, VoidCallback onTap, VoidCallback onClear) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_month, size: 20)
              : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClear),
        ),
        child: Text(value == null ? 'dd/mm/aaaa' : _dateFormat.format(value)),
      ),
    );
  }

  Widget _registroCard(Bitacora registro) {
    final color = registro.fueRechazada ? AppTheme.errorColor : AppTheme.accentDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                registro.fueRechazada ? Icons.block : Icons.check_circle_outline,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  registro.accion,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  registro.correo != null && registro.usuario != null
                      ? '${registro.quien} · ${registro.correo}'
                      : registro.quien,
                  style: const TextStyle(color: AppTheme.labelColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _dato(Icons.calendar_today_outlined, registro.fecha),
              _dato(Icons.access_time, registro.hora),
              _dato(Icons.router_outlined, registro.ip ?? 'IP desconocida'),
            ],
          ),
          if (registro.ruta != null) ...[
            const SizedBox(height: 6),
            Text(
              '${registro.metodo ?? ''} ${registro.ruta}${registro.estado != null ? ' · ${registro.estado}' : ''}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dato(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppTheme.errorColor))),
        ],
      ),
    );
  }
}