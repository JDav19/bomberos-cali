import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../util/servicios_dispositivo.dart';
import '../theme/tokens.dart';

/// Esqueleto de carga: bloques que laten suavemente en la forma del contenido
/// que va a llegar, en vez de un indicador circular generico.
class Esqueleto extends StatefulWidget {
  const Esqueleto({super.key, this.filas = 4, this.altoFila = 84});

  final int filas;
  final double altoFila;

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducir = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: 'Cargando',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = reducir ? 0.5 : _c.value;
            final color = Color.lerp(Palette.arena, Palette.arenaOscura, t)!;
            return ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Space.gutter),
              itemCount: widget.filas,
              separatorBuilder: (_, _) => const SizedBox(height: Space.m),
              itemBuilder: (_, _) => Container(
                height: widget.altoFila,
                decoration: BoxDecoration(color: color, borderRadius: Radii.card),
              ),
            );
          },
        ),
      ),
    );
  }
}

class VistaMensaje extends StatelessWidget {
  const VistaMensaje({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.accion,
    this.etiquetaAccion,
    this.colorIcono = Palette.oxido,
  });

  final PhosphorIconData icono;
  final String titulo;
  final String mensaje;
  final VoidCallback? accion;
  final String? etiquetaAccion;
  final Color colorIcono;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PhosphorIcon(icono, size: 56, color: colorIcono),
          const SizedBox(height: Space.l),
          Text(titulo, style: t.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: Space.s),
          Text(mensaje, style: t.bodyLarge, textAlign: TextAlign.center),
          if (accion != null) ...[
            const SizedBox(height: Space.xl),
            FilledButton(onPressed: accion, child: Text(etiquetaAccion ?? 'Reintentar')),
          ],
        ]),
      ),
    );
  }
}

class VistaError extends StatelessWidget {
  const VistaError({super.key, required this.alReintentar, this.mensaje});

  final VoidCallback alReintentar;
  final String? mensaje;

  @override
  Widget build(BuildContext context) => VistaMensaje(
        icono: PhosphorIconsBold.warningCircle,
        titulo: 'No pudimos cargar la información',
        mensaje: mensaje ?? 'Revise su conexión a internet e intente de nuevo.',
        accion: alReintentar,
        colorIcono: Palette.rojo,
      );
}

/// Franja que aparece arriba cuando el telefono no tiene red. Explica que el
/// reporte no se pierde: queda guardado y se envia solo.
class AvisoSinConexion extends StatelessWidget {
  const AvisoSinConexion({super.key});

  @override
  Widget build(BuildContext context) {
    final enLinea = context.select<ConexionService, bool>((c) => c.enLinea);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: enLinea
          ? const SizedBox(width: double.infinity)
          : Material(
              color: Palette.ambarSuave,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.m),
                child: Row(children: [
                  const PhosphorIcon(PhosphorIconsBold.wifiSlash, color: Palette.oxido),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Text('Sin conexión. Su reporte se guarda en el teléfono y se envía solo cuando vuelva la señal.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ]),
              ),
            ),
    );
  }
}
