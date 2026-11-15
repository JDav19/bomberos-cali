import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/servicios_dispositivo.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/marca.dart';
import '../reportes/mis_reportes.dart';
import '../reportes/models.dart';
import '../reportes/reportes_repository.dart';
import 'videollamada_screen.dart';

/// Pantalla completa cuando el radio operador inicia una videollamada.
class LlamadaEntranteScreen extends StatefulWidget {
  const LlamadaEntranteScreen({super.key, required this.radicado});

  final String radicado;

  @override
  State<LlamadaEntranteScreen> createState() => _LlamadaEntranteScreenState();
}

class _LlamadaEntranteScreenState extends State<LlamadaEntranteScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  bool _respondida = false;

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  Future<void> _contestar() async {
    if (!AppConfig.agoraListo) {
      avisar(context, 'La videollamada no está configurada en esta versión.');
      return;
    }
    _respondida = true;
    context.read<MisReportes>().descartarLlamada();
    await context.read<ReportesRepository>().responderVideollamada(widget.radicado, EstadoLlamada.aceptada);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => VideollamadaScreen(radicado: widget.radicado, esOperador: false),
    ));
  }

  Future<void> _rechazar() async {
    _respondida = true;
    context.read<MisReportes>().descartarLlamada();
    await context.read<ReportesRepository>().responderVideollamada(widget.radicado, EstadoLlamada.rechazada);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = context.select<MisReportes, Reporte?>((m) => m.porRadicado(widget.radicado));
    // El operador colgo antes de que contestara.
    if (!_respondida && r != null && r.videollamada.estado != EstadoLlamada.llamando) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_respondida) {
          _respondida = true;
          Navigator.of(context).maybePop();
        }
      });
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Palette.carbon,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(children: [
              const Spacer(),
              SizedBox(
                width: 180,
                height: 180,
                child: AnimatedBuilder(
                  animation: _pulso,
                  builder: (_, _) => CustomPaint(
                    painter: _OndasPainter(MediaQuery.of(context).disableAnimations ? 0.5 : _pulso.value),
                    child: const Center(child: BrandMark(size: 72)),
                  ),
                ),
              ),
              const SizedBox(height: Space.xl),
              Text('Bomberos de Cali', style: t.headlineLarge?.copyWith(color: Palette.ceniza)),
              const SizedBox(height: Space.s),
              Text(
                'Un radio operador quiere ver la situación en tiempo real.\nReporte ${widget.radicado}',
                style: t.bodyLarge?.copyWith(color: Palette.ceniza),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _contestar,
                icon: const PhosphorIcon(PhosphorIconsFill.videoCamera),
                label: const Text('CONTESTAR'),
              ),
              const SizedBox(height: Space.m),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.ceniza,
                  side: const BorderSide(color: Palette.ceniza, width: Sizes.border),
                ),
                onPressed: _rechazar,
                child: const Text('Ahora no puedo'),
              ),
              const SizedBox(height: Space.m),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Palette.ambar),
                onPressed: () => Enlaces.llamar(AppConfig.lineaEmergencia),
                icon: const PhosphorIcon(PhosphorIconsFill.phone),
                label: const Text('Llamar al 119'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _OndasPainter extends CustomPainter {
  _OndasPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (final fase in [0.0, 0.5]) {
      final v = (t + fase) % 1;
      canvas.drawCircle(
        c,
        size.width / 2 * (0.5 + v * 0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Palette.brasa.withValues(alpha: (1 - v) * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(_OndasPainter o) => o.t != t;
}
