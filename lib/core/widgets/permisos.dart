import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';

import '../theme/tokens.dart';

/// Pide un permiso en el momento en que se necesita, explicando antes para
/// que se usa. Si la persona lo habia negado para siempre, ofrece ir a los
/// ajustes. Devuelve `true` solo si el permiso quedo concedido.
Future<bool> pedirPermisoConExplicacion(
  BuildContext context, {
  required Permission permiso,
  required String titulo,
  required String motivo,
  required PhosphorIconData icono,
  String? siNiega,
}) async {
  var estado = await permiso.status;
  if (estado.isGranted || estado.isLimited) return true;
  if (!context.mounted) return false;

  if (estado.isPermanentlyDenied) {
    await _irAAjustes(context, titulo, siNiega ?? motivo);
    return (await permiso.status).isGranted;
  }

  final continuar = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _HojaPermiso(titulo: titulo, motivo: motivo, icono: icono),
  );
  if (continuar != true) return false;

  estado = await permiso.request();
  if (estado.isGranted || estado.isLimited) return true;
  if (estado.isPermanentlyDenied && context.mounted) {
    await _irAAjustes(context, titulo, siNiega ?? motivo);
    return (await permiso.status).isGranted;
  }
  return false;
}

Future<void> _irAAjustes(BuildContext context, String titulo, String motivo) async {
  final abrir = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text('$motivo\n\nEl permiso está desactivado. Puede activarlo en los ajustes del teléfono.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, Sizes.touch)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Abrir ajustes'),
        ),
      ],
    ),
  );
  if (abrir == true) await openAppSettings();
}

class _HojaPermiso extends StatelessWidget {
  const _HojaPermiso({required this.titulo, required this.motivo, required this.icono});
  final String titulo;
  final String motivo;
  final PhosphorIconData icono;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          PhosphorIcon(icono, size: 40, color: Palette.brasaOscura),
          const SizedBox(height: Space.m),
          Text(titulo, style: t.headlineSmall),
          const SizedBox(height: Space.s),
          Text(motivo, style: t.bodyLarge),
          const SizedBox(height: Space.xl),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONTINUAR')),
          const SizedBox(height: Space.s),
          Center(
            child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ahora no')),
          ),
        ]),
      ),
    );
  }
}
