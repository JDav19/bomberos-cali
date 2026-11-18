import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/util/servicios_dispositivo.dart';
import '../../core/widgets/categorias_ui.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/marca.dart';
import '../../core/widgets/permisos.dart';
import '../protocolo/protocolo.dart';
import '../reportes/cola_offline.dart';
import '../reportes/mis_reportes.dart';
import '../reportes/models.dart';
import 'cuestionario_screen.dart';
import 'detalles_reporte_screen.dart';
import 'pre_arribo_screen.dart';

/// Respuesta automatica al ciudadano: confirma que el reporte quedo recibido
/// (o guardado si no hay red) con su numero de radicado y su estado.
class ConfirmacionScreen extends StatefulWidget {
  const ConfirmacionScreen({super.key, required this.radicado, required this.reporteInicial});

  final String radicado;
  final Reporte reporteInicial;

  @override
  State<ConfirmacionScreen> createState() => _ConfirmacionScreenState();
}

class _ConfirmacionScreenState extends State<ConfirmacionScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _avisosActivos = true;

  @override
  void initState() {
    super.initState();
    _anim.forward();
    HapticFeedback.mediumImpact();
    Permission.notification.status.then((s) {
      if (mounted) setState(() => _avisosActivos = s.isGranted);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _activarAvisos() async {
    final ok = await pedirPermisoConExplicacion(
      context,
      permiso: Permission.notification,
      titulo: 'Avisos de su reporte',
      motivo: 'Le avisaremos en el teléfono cuando los Bomberos cambien el estado de su reporte '
          'o quieran hacerle una videollamada.',
      icono: PhosphorIconsBold.bell,
    );
    if (!mounted) return;
    if (ok) await context.read<NotificacionesService>().pedirPermiso();
    final s = await Permission.notification.status;
    if (mounted) setState(() => _avisosActivos = s.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final protocolo = context.read<Protocolo>();
    final remoto = context.select<MisReportes, Reporte?>((m) => m.porRadicado(widget.radicado));
    final item = context.watch<ColaOffline>().porRadicado(widget.radicado);
    final r = remoto ?? widget.reporteInicial;
    final enviado = remoto != null && (item == null || item.documentoEnviado);
    final archivosPendientes = item?.archivos.length ?? (remoto?.mediaPendiente ?? 0);
    final tarjeta = protocolo.tarjeta(r.tarjetaId);
    final tieneClaves = protocolo.clavesDe(r.tarjetaId).isNotEmpty && !r.cuestionarioCompleto;
    final tieneInstrucciones = tarjeta != null && tarjeta.preArribo.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).popUntil((r) => r.isFirst);
      },
      child: Pantalla(
        titulo: 'Reporte',
        atras: false,
        acciones: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Inicio'),
          ),
        ],
        cuerpo: Column(children: [
          const FranjaReflectiva(),
          Expanded(
            child: Cuerpo(hijos: [
              const SizedBox(height: Space.m),
              Center(
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (_, _) => CustomPaint(
                    size: const Size(96, 96),
                    painter: _SelloPainter(
                      progreso: Curves.easeOutCubic.transform(_anim.value),
                      color: enviado ? Palette.verde : Palette.oxido,
                      pendiente: !enviado,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.l),
              Text(
                enviado ? 'Su reporte fue recibido' : 'Reporte guardado en el teléfono',
                style: t.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.s),
              Text(
                enviado
                    ? 'Un radio operador de los Bomberos de Cali lo revisará. Puede cerrar esta pantalla.'
                    : 'No hay conexión. Se enviará solo apenas vuelva la señal; no tiene que hacer nada más.',
                style: t.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.xl),
              _TarjetaRadicado(reporte: r, enviado: enviado),
              if (archivosPendientes > 0) ...[
                const SizedBox(height: Space.m),
                _SubiendoArchivos(cantidad: archivosPendientes, enLinea: context.watch<ConexionService>().enLinea),
              ],
              if (!_avisosActivos) ...[
                const SizedBox(height: Space.m),
                _InvitarAvisos(alActivar: _activarAvisos),
              ],
              const SeparadorManguera(vertical: Space.xl),
              if (r.esRapido) ...[
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => DetallesReporteScreen(reporte: r),
                  )),
                  icon: const PhosphorIcon(PhosphorIconsBold.clipboardText),
                  label: const Text('AGREGAR DETALLES'),
                ),
                const SizedBox(height: Space.s),
                Text('Tipo de emergencia, qué ocurre y su teléfono. Es opcional y puede hacerlo después '
                    'desde "Mis reportes".', style: t.bodySmall, textAlign: TextAlign.center),
              ] else if (!protocolo.categoria(r.categoria)!.tieneTarjetas)
                Text('Para este tipo de reporte el protocolo no tiene preguntas ni instrucciones. '
                    'Si cambia la situación, llame al 119.', style: t.bodyMedium)
              else ...[
                if (tieneClaves) ...[
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => CuestionarioScreen(reporte: r),
                    )),
                    icon: const PhosphorIcon(PhosphorIconsBold.listChecks),
                    label: const Text('COMPLEMENTAR MI REPORTE'),
                  ),
                  const SizedBox(height: Space.s),
                  Text('Son pocas preguntas y es opcional.', style: t.bodySmall, textAlign: TextAlign.center),
                  const SizedBox(height: Space.m),
                ],
                if (tieneInstrucciones)
                  (tieneClaves ? OutlinedButton.icon : FilledButton.icon)(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => PreArriboScreen(tarjeta: tarjeta, radicado: r.radicado),
                    )),
                    icon: const PhosphorIcon(PhosphorIconsBold.firstAidKit),
                    label: const Text('Ver instrucciones mientras llegan'),
                  ),
              ],
              const SizedBox(height: Space.m),
              Text('Reporte de ${infoDe(r.categoria).etiqueta.toLowerCase()}'
                  '${r.tarjetaNombre != null ? ': ${r.tarjetaNombre}' : ''}.', style: t.bodySmall, textAlign: TextAlign.center),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TarjetaRadicado extends StatelessWidget {
  const _TarjetaRadicado({required this.reporte, required this.enviado});
  final Reporte reporte;
  final bool enviado;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(
        color: Palette.arena,
        borderRadius: Radii.card,
        border: Border.all(color: Palette.carbon, width: Sizes.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('NÚMERO DE RADICADO', style: t.labelSmall),
        const SizedBox(height: Space.xs),
        Row(children: [
          Expanded(
            child: Semantics(
              label: 'Radicado ${reporte.radicado}',
              child: Text(reporte.radicado, style: t.headlineMedium?.copyWith(letterSpacing: 1)),
            ),
          ),
          IconButton(
            tooltip: 'Copiar radicado',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reporte.radicado));
              avisar(context, 'Radicado copiado.');
            },
            icon: const PhosphorIcon(PhosphorIconsBold.copy),
          ),
        ]),
        const SizedBox(height: Space.s),
        Row(children: [
          ChipEstado(enviado ? reporte.estado : EstadoReporte.recibido),
          const SizedBox(width: Space.m),
          Expanded(child: Text(diaYHora(reporte.creadoEn), style: t.bodyMedium)),
        ]),
      ]),
    );
  }
}

class _SubiendoArchivos extends StatelessWidget {
  const _SubiendoArchivos({required this.cantidad, required this.enLinea});
  final int cantidad;
  final bool enLinea;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(color: Palette.arena, borderRadius: Radii.card),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            enLinea
                ? 'Subiendo $cantidad ${cantidad == 1 ? 'archivo' : 'archivos'}…'
                : '$cantidad ${cantidad == 1 ? 'archivo espera' : 'archivos esperan'} conexión',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: Space.s),
          if (enLinea) const LinearProgressIndicator(minHeight: 4),
          const SizedBox(height: Space.xs),
          Text('El reporte ya llegó; las fotos y el video se agregan cuando terminan de subir.',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class _InvitarAvisos extends StatelessWidget {
  const _InvitarAvisos({required this.alActivar});
  final VoidCallback alActivar;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
            color: Palette.ambarSuave, borderRadius: Radii.card),
        child: Row(children: [
          const PhosphorIcon(PhosphorIconsBold.bell, color: Palette.oxido),
          const SizedBox(width: Space.m),
          Expanded(child: Text('Reciba un aviso cuando cambie el estado.', style: Theme.of(context).textTheme.bodyMedium)),
          TextButton(onPressed: alActivar, child: const Text('Activar')),
        ]),
      );
}

/// Sello de envio: un circulo que se traza y un visto que aparece. Si el
/// reporte aun no salio del telefono, en lugar del visto se dibuja un reloj.
class _SelloPainter extends CustomPainter {
  _SelloPainter({required this.progreso, required this.color, required this.pendiente});

  final double progreso;
  final Color color;
  final bool pendiente;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radio = size.width / 2 - 5;
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: radio), -1.5708, 6.2832 * progreso.clamp(0, 1), false, trazo);

    final p2 = ((progreso - 0.45) / 0.55).clamp(0.0, 1.0);
    if (p2 <= 0) return;
    final path = Path();
    if (pendiente) {
      path
        ..moveTo(c.dx, c.dy - radio * 0.5)
        ..lineTo(c.dx, c.dy)
        ..lineTo(c.dx + radio * 0.35, c.dy + radio * 0.2);
    } else {
      path
        ..moveTo(c.dx - radio * 0.42, c.dy + radio * 0.02)
        ..lineTo(c.dx - radio * 0.1, c.dy + radio * 0.34)
        ..lineTo(c.dx + radio * 0.46, c.dy - radio * 0.3);
    }
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * p2), trazo);
    }
  }

  @override
  bool shouldRepaint(_SelloPainter o) => o.progreso != progreso || o.color != color || o.pendiente != pendiente;
}
