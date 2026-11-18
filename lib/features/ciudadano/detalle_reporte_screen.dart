import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/estilos.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/util/servicios_dispositivo.dart';
import '../../core/widgets/categorias_ui.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/galeria.dart';
import '../../core/widgets/marca.dart';
import '../protocolo/protocolo.dart';
import '../reportes/cola_offline.dart';
import '../reportes/mis_reportes.dart';
import '../reportes/models.dart';
import '../videollamada/llamada_entrante_screen.dart';
import 'cuestionario_screen.dart';
import 'detalles_reporte_screen.dart';
import 'pre_arribo_screen.dart';

/// Detalle de un reporte del ciudadano, en tiempo real.
class DetalleReporteScreen extends StatelessWidget {
  const DetalleReporteScreen({super.key, required this.radicado});

  final String radicado;

  @override
  Widget build(BuildContext context) {
    final mis = context.watch<MisReportes>();
    final cola = context.watch<ColaOffline>();
    final remoto = mis.porRadicado(radicado);
    final local = cola.porRadicado(radicado);
    final r = remoto ?? local?.reporte;
    final protocolo = context.read<Protocolo>();
    final t = Theme.of(context).textTheme;

    if (r == null) {
      return const Pantalla(
        titulo: 'Reporte',
        cuerpo: VistaCargando(),
      );
    }
    final enviado = remoto != null;
    final tarjeta = protocolo.tarjeta(r.tarjetaId);
    final claves = protocolo.clavesDe(r.tarjetaId);
    final info = infoDe(r.categoria);

    return Pantalla(
      titulo: 'Reporte',
      cuerpo: Cuerpo(hijos: [
        Row(children: [
          PhosphorIcon(info.icono, size: 36, color: Palette.oxido),
          const SizedBox(width: Space.m),
          Expanded(child: Text(r.tarjetaNombre ?? info.etiqueta, style: t.headlineSmall)),
        ]),
        const SizedBox(height: Space.s),
        Text(r.radicado, style: t.titleMedium?.copyWith(letterSpacing: 0.8)),
        Text('Enviado ${diaYHora(r.creadoEn)}', style: t.bodySmall),
        const SizedBox(height: Space.l),
        if (r.videollamada.estado == EstadoLlamada.llamando) ...[
          _AvisoLlamada(radicado: r.radicado),
          const SizedBox(height: Space.l),
        ],
        const EncabezadoSeccion('Estado'),
        if (!enviado)
          Container(
            padding: const EdgeInsets.all(Space.m),
            decoration: BoxDecoration(color: Palette.ambarSuave, borderRadius: Radii.card),
            child: Row(children: [
              const PhosphorIcon(PhosphorIconsBold.cloudArrowUp, color: Palette.oxido),
              const SizedBox(width: Space.m),
              Expanded(
                child: Text('Guardado en el teléfono. Se enviará cuando haya conexión.', style: t.bodyMedium),
              ),
            ]),
          )
        else
          _LineaEstados(reporte: r),
        const SeparadorManguera(),
        const EncabezadoSeccion('Ubicación'),
        if (r.ubicacion != null) ...[
          Text('${r.ubicacion!.lat.toStringAsFixed(5)}, ${r.ubicacion!.lng.toStringAsFixed(5)}', style: t.bodyLarge),
          if (r.referencia != null) Text(r.referencia!, style: t.bodyMedium),
          const SizedBox(height: Space.s),
          OutlinedButton.icon(
            onPressed: () => Enlaces.mapa(r.ubicacion!.lat, r.ubicacion!.lng),
            icon: const PhosphorIcon(PhosphorIconsBold.mapTrifold),
            label: const Text('Ver en Google Maps'),
          ),
        ] else
          Text(r.referencia ?? 'Sin ubicación GPS.', style: t.bodyLarge),
        if (r.descripcion != null) ...[
          const SeparadorManguera(),
          const EncabezadoSeccion('Descripción'),
          Text(r.descripcion!, style: t.bodyLarge),
        ],
        const SeparadorManguera(),
        const EncabezadoSeccion('Fotos y video'),
        GaleriaMedia(items: r.media, pendientes: local?.archivos.length ?? r.mediaPendiente),
        if (r.respuestas.isNotEmpty) ...[
          const SeparadorManguera(),
          const EncabezadoSeccion('Sus respuestas'),
          for (final q in claves)
            if (r.respuestas[q.clave] != null) _Respuesta(pregunta: q, valor: r.respuestas[q.clave]!),
        ],
        const SizedBox(height: Space.xl),
        if (r.estado.activo) ...[
          (r.esRapido ? FilledButton.icon : OutlinedButton.icon)(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => DetallesReporteScreen(reporte: r))),
            icon: const PhosphorIcon(PhosphorIconsBold.clipboardText),
            label: Text(r.esRapido ? 'AGREGAR DETALLES' : 'Editar detalles'),
          ),
          const SizedBox(height: Space.s),
        ],
        if (claves.isNotEmpty && !r.cuestionarioCompleto)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CuestionarioScreen(reporte: r))),
            icon: const PhosphorIcon(PhosphorIconsBold.listChecks),
            label: const Text('COMPLEMENTAR MI REPORTE'),
          ),
        if (tarjeta != null && tarjeta.preArribo.isNotEmpty) ...[
          const SizedBox(height: Space.s),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => PreArriboScreen(tarjeta: tarjeta, radicado: r.radicado))),
            icon: const PhosphorIcon(PhosphorIconsBold.firstAidKit),
            label: const Text('Ver instrucciones'),
          ),
        ],
      ]),
    );
  }
}

class VistaCargando extends StatelessWidget {
  const VistaCargando({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: BrandMark(size: 64));
}

class _AvisoLlamada extends StatelessWidget {
  const _AvisoLlamada({required this.radicado});
  final String radicado;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Space.l),
        decoration: BoxDecoration(color: Palette.rojoSuave, borderRadius: Radii.card, border: Border.all(color: Palette.rojo, width: 2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Los Bomberos quieren hacer una videollamada', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.m),
          FilledButton.icon(
            style: Estilos.emergencia(),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => LlamadaEntranteScreen(radicado: radicado))),
            icon: const PhosphorIcon(PhosphorIconsFill.videoCamera),
            label: const Text('CONTESTAR'),
          ),
        ]),
      );
}

class _Respuesta extends StatelessWidget {
  const _Respuesta({required this.pregunta, required this.valor});
  final PreguntaClave pregunta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = switch (valor) { 'si' => 'Sí', 'no' => 'No', 'nosabe' => 'No sabe', _ => valor };
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(textoPregunta(pregunta.texto), style: t.bodySmall),
        Text(v, style: t.titleMedium),
      ]),
    );
  }
}

/// Las cinco etapas, marcando hasta donde va el reporte.
class _LineaEstados extends StatelessWidget {
  const _LineaEstados({required this.reporte});
  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final actual = reporte.estado.index;
    final horas = {for (final h in reporte.historial) h.estado: h.en};
    return Column(children: [
      for (final e in EstadoReporte.values)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 28,
              child: Column(children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: e.index <= actual ? (e == reporte.estado ? Palette.brasa : Palette.carbon) : Palette.ceniza,
                    border: Border.all(color: e.index <= actual ? Palette.carbon : Palette.arenaOscura, width: 2),
                  ),
                ),
                if (e != EstadoReporte.values.last)
                  Expanded(child: Container(width: 3, color: e.index < actual ? Palette.carbon : Palette.arenaOscura)),
              ]),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: Space.m),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.etiqueta,
                      style: t.titleMedium?.copyWith(
                          fontWeight: e == reporte.estado ? FontWeight.w700 : FontWeight.w500,
                          color: e.index <= actual ? Palette.carbon : Palette.textoSuave)),
                  if (horas[e] != null) Text(diaYHora(horas[e]!), style: t.bodySmall),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}
