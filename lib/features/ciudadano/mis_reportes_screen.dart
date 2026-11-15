import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/widgets/categorias_ui.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/estados.dart';
import '../reportes/cola_offline.dart';
import '../reportes/mis_reportes.dart';
import '../reportes/models.dart';
import 'detalle_reporte_screen.dart';

class MisReportesScreen extends StatelessWidget {
  const MisReportesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mis = context.watch<MisReportes>();
    final cola = context.watch<ColaOffline>();
    final remotos = mis.reportes;
    final ids = remotos.map((r) => r.radicado).toSet();
    // Reportes que aun no llegaron a la nube (guardados en el telefono).
    final locales = cola.items.where((i) => !ids.contains(i.radicado)).map((i) => i.reporte).toList();
    final todos = [...locales, ...remotos];

    if (mis.cargando && todos.isEmpty) return const Esqueleto();
    if (mis.error != null && todos.isEmpty) return VistaError(alReintentar: mis.reintentar);
    if (todos.isEmpty) {
      return const VistaMensaje(
        icono: PhosphorIconsBold.clipboardText,
        titulo: 'Aún no ha enviado reportes',
        mensaje: 'Cuando envíe uno, aquí verá su estado y podrá consultarlo.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, Space.xxl),
      itemCount: todos.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.m),
      itemBuilder: (context, i) {
        final r = todos[i];
        return _TarjetaReporte(reporte: r, local: !ids.contains(r.radicado));
      },
    );
  }
}

class _TarjetaReporte extends StatelessWidget {
  const _TarjetaReporte({required this.reporte, required this.local});
  final Reporte reporte;
  final bool local;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = reporte;
    return Card(
      child: InkWell(
        borderRadius: Radii.card,
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => DetalleReporteScreen(radicado: r.radicado))),
        child: Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PhosphorIcon(infoDe(r.categoria).icono, color: Palette.oxido, size: 30),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.tarjetaNombre ?? r.categoriaNombre, style: t.titleMedium),
                const SizedBox(height: 2),
                Text('${r.radicado}\n${diaYHora(r.creadoEn)}', style: t.bodySmall),
                const SizedBox(height: Space.s),
                Wrap(spacing: Space.s, runSpacing: Space.xs, children: [
                  if (local)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xs + 2),
                      decoration: BoxDecoration(color: Palette.ambarSuave, borderRadius: Radii.chip),
                      child: Text('Pendiente de envío', style: t.labelMedium?.copyWith(color: Palette.oxido)),
                    )
                  else
                    ChipEstado(r.estado),
                  if (r.videollamada.estado == EstadoLlamada.llamando)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xs + 2),
                      decoration: BoxDecoration(color: Palette.rojo, borderRadius: Radii.chip),
                      child: Text('Videollamada', style: t.labelMedium?.copyWith(color: Colors.white)),
                    ),
                ]),
              ]),
            ),
            const PhosphorIcon(PhosphorIconsBold.caretRight, color: Palette.textoSuave),
          ]),
        ),
      ),
    );
  }
}
