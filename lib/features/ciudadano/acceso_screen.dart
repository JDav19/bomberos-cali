import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/widgets/comunes.dart';
import '../auth/auth_service.dart';

/// Ingreso y registro. El operador entra por aqui con su cuenta: el rol se lee
/// de Firestore y la app cambia sola a la vista de radio operador.
class AccesoScreen extends StatefulWidget {
  const AccesoScreen({super.key, required this.registro});

  final bool registro;

  @override
  State<AccesoScreen> createState() => _AccesoScreenState();
}

class _AccesoScreenState extends State<AccesoScreen> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _nombre = TextEditingController();
  final _tel = TextEditingController();
  late bool _registro = widget.registro;
  bool _ver = false;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    _nombre.dispose();
    _tel.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    try {
      if (_registro) {
        await auth.registrar(
          nombre: _nombre.text,
          telefono: normalizarTelefono(_tel.text),
          correo: _correo.text,
          clave: _clave.text,
        );
      } else {
        await auth.ingresar(_correo.text, _clave.text);
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = mensajeAuth(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Pantalla(
      titulo: _registro ? 'Crear cuenta' : 'Ingresar',
      cuerpo: Form(
        key: _form,
        child: Cuerpo(hijos: [
          if (_registro) ...[
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Escriba su nombre.' : null,
            ),
            const SizedBox(height: Space.m),
            TextFormField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
              decoration: const InputDecoration(labelText: 'Teléfono de contacto'),
              validator: validarTelefono,
            ),
            const SizedBox(height: Space.m),
          ],
          TextFormField(
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Correo electrónico'),
            validator: (v) => (v ?? '').contains('@') && (v ?? '').contains('.') ? null : 'Escriba un correo válido.',
          ),
          const SizedBox(height: Space.m),
          TextFormField(
            controller: _clave,
            obscureText: !_ver,
            autofillHints: [_registro ? AutofillHints.newPassword : AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Contraseña',
              suffixIcon: IconButton(
                tooltip: _ver ? 'Ocultar contraseña' : 'Mostrar contraseña',
                onPressed: () => setState(() => _ver = !_ver),
                icon: PhosphorIcon(_ver ? PhosphorIconsBold.eyeSlash : PhosphorIconsBold.eye),
              ),
            ),
            validator: (v) => (v ?? '').length < 6 ? 'Use al menos 6 caracteres.' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.m),
            Container(
              padding: const EdgeInsets.all(Space.m),
              decoration: BoxDecoration(color: Palette.rojoSuave, borderRadius: Radii.card),
              child: Row(children: [
                const PhosphorIcon(PhosphorIconsBold.warningCircle, color: Palette.rojo),
                const SizedBox(width: Space.m),
                Expanded(child: Text(_error!, style: t.bodyMedium)),
              ]),
            ),
          ],
          const SizedBox(height: Space.xl),
          FilledButton(
            onPressed: _enviando ? null : _enviar,
            child: _enviando
                ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3))
                : Text(_registro ? 'CREAR CUENTA' : 'INGRESAR'),
          ),
          const SizedBox(height: Space.m),
          Center(
            child: TextButton(
              onPressed: _enviando ? null : () => setState(() {
                    _registro = !_registro;
                    _error = null;
                  }),
              child: Text(_registro ? 'Ya tengo cuenta' : 'Crear una cuenta'),
            ),
          ),
        ]),
      ),
    );
  }
}
