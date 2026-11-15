import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/widgets/categorias_ui.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/marca.dart';
import '../reportes/cola_offline.dart';
import '../reportes/mis_reportes.dart';
import '../reportes/models.dart';
import 'ciudadano_shell.dart';
import 'detalle_reporte_screen.dart';
import 'tipo_emergencia_screen.dart';

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final reportes = context.watch<MisReportes>().reportes;
    final pendientes = context.watch<ColaOffline>().items;
    final ultimo = reportes.isEmpty ? null : reportes.first;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const FranjaReflectiva(),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.gutter),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Aparece(
              child: Text('¿Qué está pasando?', style: t.displaySmall),
            ),
            const SizedBox(height: Space.s),
            Text(
              'Su ubicación se envía sola. Si hay peligro inmediato para la vida, llame también al 119.',
              style: t.bodyLarge,
            ),
            const Spacer(),
            if (pendientes.isNotEmpty) ...[
              _AvisoPendientes(cantidad: pendientes.length),
              separadorM,
            ],
            if (ultimo != null) ...[
              _UltimoReporte(reporte: ultimo),
              const SizedBox(height: Space.l),
            ],
            // La accion principal queda abajo, al alcance del pulgar.
            const _BotonReportar(),
          ]),
        ),
      ),
    ]);
  }
}

class _BotonReportar extends StatelessWidget {
  const _BotonReportar();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Reportar una emergencia',
      child: Material(
        color: Palette.rojo,
        borderRadius: BorderRadius.circular(Radii.l),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.l),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TipoEmergenciaScreen())),
          child: Container(
            constraints: const BoxConstraints(minHeight: 112),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.l),
              boxShadow: Elevations.raised,
            ),
            padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.l),
            child: Row(children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: Palette.ceniza, shape: BoxShape.circle),
                child: const Center(child: BrandMark(size: 34, color: Palette.rojo, inner: Palette.ambar)),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('REPORTAR EMERGENCIA',
                      style: t.headlineMedium?.copyWith(color: Colors.white, letterSpacing: 0.6, height: 1.05)),
                  const SizedBox(height: 2),
                  Text('Tipo, ubicación y fotos',
                      style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                ]),
              ),
              const PhosphorIcon(PhosphorIconsBold.caretRight, color: Colors.white, size: 28),
            ]),
          ),
        ),
      ),
    );
  }
}

class _UltimoReporte extends StatelessWidget {
  const _UltimoReporte({required this.reporte});
  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: Radii.card,
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => DetalleReporteScreen(radicado: reporte.radicado))),
        child: Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Row(children: [
            PhosphorIcon(infoDe(reporte.categoria).icono, color: Palette.oxido, size: 30),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Su último reporte', style: t.labelSmall),
                Text(reporte.tarjetaNombre ?? reporte.categoriaNombre,
                    style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${reporte.radicado} · ${hace(reporte.creadoEn)}', style: t.bodySmall),
              ]),
            ),
            const SizedBox(width: Space.s),
            ChipEstado(reporte.estado),
          ]),
        ),
      ),
    );
  }
}

class _AvisoPendientes extends StatelessWidget {
  const _AvisoPendientes({required this.cantidad});
  final int cantidad;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(color: Palette.ambarSuave, borderRadius: Radii.card),
        child: Row(children: [
          const PhosphorIcon(PhosphorIconsBold.cloudArrowUp, color: Palette.oxido),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(
              cantidad == 1
                  ? '1 reporte está guardado en el teléfono y se enviará apenas haya conexión.'
                  : '$cantidad reportes están guardados en el teléfono y se enviarán apenas haya conexión.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, Sizes.touch)),
            onPressed: () => context.read<ColaOffline>().procesar(ignorarEspera: true),
            child: const Text('Reintentar'),
          ),
        ]),
      );
}
