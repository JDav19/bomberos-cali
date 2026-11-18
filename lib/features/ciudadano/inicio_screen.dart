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
import 'reporte_rapido.dart';
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
              child: Text('¿Hay una emergencia?', style: t.displaySmall),
            ),
            const SizedBox(height: Space.s),
            Text(
              'Tome una foto: se envía sola con su ubicación. Los detalles los completa después.',
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
            const _BotonFotoRapida(),
            const SizedBox(height: Space.m),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TipoEmergenciaScreen())),
              icon: const PhosphorIcon(PhosphorIconsBold.plus),
              label: const Text('Reportar con más detalle'),
            ),
            const SizedBox(height: Space.s),
            Text('Tómela desde un lugar seguro: no se arriesgue por una foto.',
                style: t.bodySmall, textAlign: TextAlign.center),
          ]),
        ),
      ),
    ]);
  }
}

class _BotonFotoRapida extends StatelessWidget {
  const _BotonFotoRapida();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Tomar una foto y enviar el reporte con su ubicación',
      child: Material(
        color: Palette.rojo,
        borderRadius: BorderRadius.circular(Radii.l),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.l),
          onTap: () => iniciarReporteRapido(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 132),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.l),
              border: Border.all(color: Palette.brasa, width: 3),
              boxShadow: Elevations.raised,
            ),
            padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.l),
            child: Row(children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(color: Palette.brasa, shape: BoxShape.circle),
                child: const Center(child: PhosphorIcon(PhosphorIconsBold.camera, color: Palette.carbon, size: 38)),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('FOTO Y ENVIAR',
                      style: t.headlineLarge?.copyWith(color: Colors.white, letterSpacing: 0.6, height: 1.0)),
                  const SizedBox(height: Space.xs),
                  Text('Sale sola con su ubicación',
                      style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.95))),
                ]),
              ),
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
