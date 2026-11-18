import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/widgets/comunes.dart';
import '../auth/auth_service.dart';
import 'acceso_screen.dart';
import 'privacidad_screen.dart';

class CuentaScreen extends StatelessWidget {
  const CuentaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return auth.registrado ? const _PerfilRegistrado() : const _SinCuenta();
  }
}

class _SinCuenta extends StatelessWidget {
  const _SinCuenta();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Cuerpo(hijos: [
      Text('No necesita una cuenta para reportar', style: t.headlineSmall),
      const SizedBox(height: Space.s),
      Text(
          'Si crea una cuenta, su nombre y su teléfono se llenan solos en cada reporte y puede ver su historial '
          'desde cualquier teléfono.',
          style: t.bodyLarge),
      const SizedBox(height: Space.xl),
      FilledButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const AccesoScreen(registro: true))),
        child: const Text('CREAR CUENTA'),
      ),
      const SizedBox(height: Space.m),
      OutlinedButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const AccesoScreen(registro: false))),
        child: const Text('Ya tengo cuenta'),
      ),
      const SizedBox(height: Space.xl),
      const _EnlacePrivacidad(),
    ]);
  }
}

class _PerfilRegistrado extends StatefulWidget {
  const _PerfilRegistrado();

  @override
  State<_PerfilRegistrado> createState() => _PerfilRegistradoState();
}

class _PerfilRegistradoState extends State<_PerfilRegistrado> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _tel;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AuthService>().perfil;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _tel = TextEditingController(text: p?.telefono ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _tel.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await context.read<AuthService>().actualizarPerfil(nombre: _nombre.text, telefono: normalizarTelefono(_tel.text));
      if (mounted) avisar(context, 'Datos guardados.');
    } catch (_) {
      if (mounted) avisar(context, 'No se pudo guardar. Revise su conexión.');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.watch<AuthService>().perfil;
    return Cuerpo(hijos: [
      Row(children: [
        const PhosphorIcon(PhosphorIconsBold.userCircle, size: 44, color: Palette.oxido),
        const SizedBox(width: Space.m),
        Expanded(child: Text(p?.correo ?? '', style: t.titleMedium)),
      ]),
      const SizedBox(height: Space.xl),
      const EncabezadoSeccion('Datos para los reportes'),
      Text('Se usan para llenar solos el nombre y el teléfono cuando reporta.', style: t.bodyMedium),
      const SizedBox(height: Space.l),
      Form(
        key: _form,
        child: Column(children: [
          TextFormField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (v) => (v ?? '').trim().length < 2 ? 'Escriba su nombre.' : null,
          ),
          const SizedBox(height: Space.m),
          TextFormField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
            decoration: const InputDecoration(labelText: 'Teléfono de contacto'),
            validator: validarTelefono,
          ),
        ]),
      ),
      const SizedBox(height: Space.xl),
      FilledButton(
        onPressed: _guardando ? null : _guardar,
        child: _guardando
            ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3))
            : const Text('GUARDAR'),
      ),
      const SizedBox(height: Space.m),
      OutlinedButton(onPressed: () => context.read<AuthService>().salir(), child: const Text('Cerrar sesión')),
      const SizedBox(height: Space.m),
      const _EnlacePrivacidad(),
    ]);
  }
}

class _EnlacePrivacidad extends StatelessWidget {
  const _EnlacePrivacidad();

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () =>
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacidadScreen())),
        icon: const PhosphorIcon(PhosphorIconsBold.eye),
        label: const Text('Qué datos recoge la aplicación'),
      );
}
