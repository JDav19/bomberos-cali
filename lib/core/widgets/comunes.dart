import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';

import '../../features/reportes/models.dart';
import '../config/app_config.dart';
import '../theme/tokens.dart';
import '../util/servicios_dispositivo.dart';
import 'estados.dart';

/// Boton compacto del 119, siempre en la barra superior. Abre el marcador del
/// telefono con el numero listo: la app complementa la linea, no la reemplaza.
class Boton119 extends StatelessWidget {
  const Boton119({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: Space.m),
        child: Semantics(
          button: true,
          label: 'Llamar a la línea 119',
          child: Material(
            color: Palette.rojo,
            borderRadius: Radii.control,
            child: InkWell(
              borderRadius: Radii.control,
              onTap: () => Enlaces.llamar(AppConfig.lineaEmergencia),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sizes.touch, minWidth: Sizes.touch),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.m),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const PhosphorIcon(PhosphorIconsFill.phone, color: Colors.white, size: 20),
                    const SizedBox(width: Space.xs + 2),
                    Text('119',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white, letterSpacing: 0.5)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Pantalla base: barra con el 119 siempre a la vista y aviso de conexion.
class Pantalla extends StatelessWidget {
  const Pantalla({
    super.key,
    required this.titulo,
    required this.cuerpo,
    this.acciones = const [],
    this.abajo,
    this.mostrar119 = true,
    this.atras = true,
  });

  final String titulo;
  final Widget cuerpo;
  final List<Widget> acciones;
  final Widget? abajo;
  final bool mostrar119;
  final bool atras;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: atras,
          title: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [...acciones, if (mostrar119) const Boton119()],
        ),
        body: Column(children: [const AvisoSinConexion(), Expanded(child: cuerpo)]),
        bottomNavigationBar: abajo,
      );
}

/// Cuerpo con margen lateral comun y desplazamiento.
class Cuerpo extends StatelessWidget {
  const Cuerpo({super.key, required this.hijos, this.relleno});
  final List<Widget> hijos;
  final EdgeInsets? relleno;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: relleno ?? const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, Space.xxl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos),
      );
}

class ChipEstado extends StatelessWidget {
  const ChipEstado(this.estado, {super.key});
  final EstadoReporte estado;

  @override
  Widget build(BuildContext context) {
    final (fondo, texto, icono) = switch (estado) {
      EstadoReporte.recibido => (Palette.arenaOscura, Palette.carbon, PhosphorIconsBold.tray),
      EstadoReporte.enVerificacion => (Palette.ambarSuave, Palette.oxido, PhosphorIconsBold.magnifyingGlass),
      EstadoReporte.despachado => (Palette.brasa, Palette.carbon, PhosphorIconsBold.truck),
      EstadoReporte.atendido => (Palette.verdeSuave, Palette.verde, PhosphorIconsBold.checkCircle),
      EstadoReporte.cerrado => (Palette.arena, Palette.textoSuave, PhosphorIconsBold.lockSimple),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.xs + 2),
      decoration: BoxDecoration(color: fondo, borderRadius: Radii.chip),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        PhosphorIcon(icono, size: 16, color: texto),
        const SizedBox(width: Space.xs + 2),
        Text(estado.etiqueta, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: texto)),
      ]),
    );
  }
}

class InsigniaPrioridad extends StatelessWidget {
  const InsigniaPrioridad(this.prioridad, {super.key});
  final Prioridad prioridad;

  @override
  Widget build(BuildContext context) {
    final (fondo, texto) = switch (prioridad) {
      Prioridad.critica => (Palette.rojo, Colors.white),
      Prioridad.alta => (Palette.oxido, Colors.white),
      Prioridad.media => (Palette.ambar, Palette.carbon),
      Prioridad.baja => (Palette.arenaOscura, Palette.carbon),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s + 2, vertical: Space.xs),
      decoration: BoxDecoration(color: fondo, borderRadius: Radii.chip),
      child: Text(prioridad.etiqueta.toUpperCase(),
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: texto, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );
  }
}

class EncabezadoSeccion extends StatelessWidget {
  const EncabezadoSeccion(this.texto, {super.key, this.trailing});
  final String texto;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.s),
        child: Row(children: [
          Expanded(
            child: Text(texto.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Palette.oxido, letterSpacing: 1)),
          ),
          ?trailing,
        ]),
      );
}

/// Muestra un mensaje breve de confirmacion o error.
void avisar(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}
