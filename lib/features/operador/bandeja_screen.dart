import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/widgets/categorias_ui.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/estados.dart';
import '../reportes/agrupacion.dart';
import '../reportes/models.dart';
import 'detalle_operador_screen.dart';
import 'operador_controller.dart';

class BandejaScreen extends StatefulWidget {
  const BandejaScreen({super.key});

  @override
  State<BandejaScreen> createState() => _BandejaScreenState();
}

class _BandejaScreenState extends State<BandejaScreen> {
  OperadorController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl ??= context.read<OperadorController>()
      ..alNuevo = (r) {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        avisar(context, 'Nuevo reporte: ${r.tarjetaNombre ?? r.categoriaNombre} (${r.prioridad.etiqueta})');
      };
  }

  @override
  void dispose() {
    _ctrl?.alNuevo = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperadorController>();
    final t = Theme.of(context).textTheme;
    final items = c.bandeja;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, Space.s),
        child: Row(children: [
          Expanded(
            child: SegmentedButton<FiltroBandeja>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: FiltroBandeja.activos, label: Text('Activos (${c.activos.length})')),
                ButtonSegment(value: FiltroBandeja.todos, label: Text('Todos (${c.todos.length})')),
              ],
              selected: {c.filtro},
              onSelectionChanged: (s) => c.cambiarFiltro(s.first),
            ),
          ),
        ]),
      ),
      Expanded(
        child: c.cargando
            ? const Esqueleto(altoFila: 96)
            : c.error != null
                ? VistaError(
                    alReintentar: context.read<OperadorController>().reintentar,
                    mensaje: 'No se pudieron leer los reportes. Verifique que esta cuenta tenga rol de operador.',
                  )
                : items.isEmpty
                    ? const VistaMensaje(
                        icono: PhosphorIconsBold.tray,
                        titulo: 'No hay reportes',
                        mensaje: 'Los reportes nuevos aparecen aquí al instante, ordenados por prioridad.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s, Space.gutter, Space.xxl),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Space.m),
                        itemBuilder: (context, i) => items[i].esGrupo
                            ? _TarjetaGrupo(grupo: items[i].grupo)
                            : TarjetaReporteOperador(reporte: items[i].grupo.reportes.first),
                      ),
      ),
      if (!c.cargando && c.error == null)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s),
          child: Text('Ordenado por prioridad y tiempo de espera', style: t.bodySmall),
        ),
    ]);
  }
}

class TarjetaReporteOperador extends StatelessWidget {
  const TarjetaReporteOperador({super.key, required this.reporte, this.compacta = false});

  final Reporte reporte;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = reporte;
    final activo = r.estado.activo;
    final color = switch (r.prioridad) {
      Prioridad.critica => Palette.rojo,
      Prioridad.alta => Palette.oxido,
      Prioridad.media => Palette.ambar,
      Prioridad.baja => Palette.arenaOscura,
    };
    return Opacity(
      opacity: activo ? 1 : 0.65,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => DetalleOperadorScreen(radicado: r.radicado))),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 8, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(Space.m),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      PhosphorIcon(infoDe(r.categoria).icono, size: 22, color: Palette.oxido),
                      const SizedBox(width: Space.s),
                      Expanded(
                        child: Text(r.tarjetaNombre ?? r.categoriaNombre,
                            style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      InsigniaPrioridad(r.prioridad),
                    ]),
                    const SizedBox(height: Space.xs),
                    Text('${r.radicado} · ${hace(r.creadoEn)}', style: t.bodySmall),
                    if (!compacta) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        r.referencia ?? r.descripcion ?? (r.ubicacion != null ? 'Ubicación GPS enviada' : 'Sin ubicación'),
                        style: t.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: Space.s),
                    Wrap(spacing: Space.s, runSpacing: Space.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      ChipEstado(r.estado),
                      if (r.media.isNotEmpty || r.mediaPendiente > 0)
                        _Dato(icono: PhosphorIconsBold.images, texto: '${r.media.length}${r.mediaPendiente > 0 ? ' (+${r.mediaPendiente})' : ''}'),
                      if (r.cuestionarioCompleto) const _Dato(icono: PhosphorIconsBold.listChecks, texto: 'Respondió'),
                      if (r.videollamada.activa) const _Dato(icono: PhosphorIconsBold.videoCamera, texto: 'En llamada'),
                      if (r.ubicacion == null) const _Dato(icono: PhosphorIconsBold.mapPin, texto: 'Sin GPS'),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});
  final PhosphorIconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        PhosphorIcon(icono, size: 16, color: Palette.textoSuave),
        const SizedBox(width: 4),
        Text(texto, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

/// Grupo de reportes cercanos: posible mismo incidente.
class _TarjetaGrupo extends StatefulWidget {
  const _TarjetaGrupo({required this.grupo});
  final GrupoReportes grupo;

  @override
  State<_TarjetaGrupo> createState() => _TarjetaGrupoState();
}

class _TarjetaGrupoState extends State<_TarjetaGrupo> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final g = widget.grupo;
    final minutos = g.ultimo.difference(g.primero).inMinutes;
    return Container(
      decoration: BoxDecoration(
        color: Palette.ambarSuave,
        borderRadius: Radii.card,
        border: Border.all(color: Palette.oxido, width: 1.5),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: Radii.card,
          onTap: () => setState(() => _abierto = !_abierto),
          child: Padding(
            padding: const EdgeInsets.all(Space.m),
            child: Row(children: [
              const PhosphorIcon(PhosphorIconsBold.stack, color: Palette.oxido, size: 28),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Posible mismo incidente', style: t.titleMedium),
                  Text(
                    '${g.reportes.length} reportes a menos de ${radioAgrupacionM.round()} m'
                    '${minutos > 0 ? ' en $minutos min' : ''}',
                    style: t.bodySmall?.copyWith(color: Palette.carbon),
                  ),
                ]),
              ),
              InsigniaPrioridad(g.prioridad),
              const SizedBox(width: Space.s),
              AnimatedRotation(
                turns: _abierto ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const PhosphorIcon(PhosphorIconsBold.caretDown),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _abierto
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(Space.s, 0, Space.s, Space.s),
                  child: Column(children: [
                    for (final r in g.reportes) ...[
                      TarjetaReporteOperador(reporte: r, compacta: true),
                      const SizedBox(height: Space.s),
                    ],
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}
