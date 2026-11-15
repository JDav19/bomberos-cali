import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/categorias_ui.dart';
import '../../core/widgets/comunes.dart';
import '../protocolo/protocolo.dart';
import 'formulario_reporte_screen.dart';

/// Primer paso: que tipo de emergencia es. Una sola pulsacion lleva al
/// formulario, donde el tipo especifico (la tarjeta guia) es opcional.
class TipoEmergenciaScreen extends StatelessWidget {
  const TipoEmergenciaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final protocolo = context.read<Protocolo>();
    final t = Theme.of(context).textTheme;
    return Pantalla(
      titulo: 'Tipo de emergencia',
      cuerpo: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, Space.xxl),
        itemCount: protocolo.categorias.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: Space.m),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Text('Elija la que más se parezca. Después podrá precisar.', style: t.bodyLarge),
            );
          }
          final c = protocolo.categorias[i - 1];
          final info = infoDe(c.codigo);
          return Material(
            color: Palette.arena,
            borderRadius: Radii.card,
            child: InkWell(
              borderRadius: Radii.card,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => FormularioReporteScreen(categoria: c),
              )),
              child: Container(
                constraints: const BoxConstraints(minHeight: 84),
                decoration: BoxDecoration(
                  borderRadius: Radii.card,
                  border: Border.all(color: Palette.arenaOscura),
                ),
                padding: const EdgeInsets.all(Space.m),
                child: Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Palette.brasa, borderRadius: BorderRadius.circular(Radii.m)),
                    child: Center(child: PhosphorIcon(info.icono, color: Palette.carbon, size: 30)),
                  ),
                  const SizedBox(width: Space.l),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(info.etiqueta, style: t.titleLarge),
                      const SizedBox(height: 2),
                      Text(info.ayuda, style: t.bodySmall),
                    ]),
                  ),
                  const PhosphorIcon(PhosphorIconsBold.caretRight, color: Palette.textoSuave),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
