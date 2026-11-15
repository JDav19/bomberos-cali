import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/estilos.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/servicios_dispositivo.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/marca.dart';
import '../protocolo/protocolo.dart';
import 'pre_arribo_screen.dart';

/// Recorre un procedimiento del protocolo (RCP, OVACE, parto...) nodo por
/// nodo, con los mismos botones y textos de las diapositivas.
class ProcedimientoScreen extends StatefulWidget {
  const ProcedimientoScreen({super.key, required this.grupoId, required this.nodoInicial});

  final String grupoId;
  final int nodoInicial;

  @override
  State<ProcedimientoScreen> createState() => _ProcedimientoScreenState();
}

class _ProcedimientoScreenState extends State<ProcedimientoScreen> {
  late final List<int> _historial = [widget.nodoInicial];

  void _ir(OpcionNodo o, Protocolo p) {
    if (o.volver) {
      if (_historial.length > 1) setState(() => _historial.removeLast());
      return;
    }
    final info = o.destinoInfo;
    if (info != null && info.esTarjeta) {
      final tarjeta = p.tarjeta(info.id);
      if (tarjeta != null && tarjeta.preArribo.isNotEmpty) {
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PreArriboScreen(tarjeta: tarjeta)));
      }
      return;
    }
    final d = o.destino;
    if (d != null && p.nodos.containsKey(d)) {
      final grupoDestino = p.nodos[d]!.grupo;
      if (grupoDestino == widget.grupoId) {
        setState(() => _historial.add(d));
      } else {
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ProcedimientoScreen(grupoId: grupoDestino, nodoInicial: d),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.read<Protocolo>();
    final t = Theme.of(context).textTheme;
    final nodo = p.nodos[_historial.last];
    final grupo = p.grupos[widget.grupoId];
    if (nodo == null || grupo == null) {
      return const Pantalla(titulo: 'Procedimiento', cuerpo: SizedBox.shrink());
    }
    // Opciones con destino util dentro de la app.
    final opciones = nodo.opciones.where((o) {
      if (o.volver) return _historial.length > 1;
      final i = o.destinoInfo;
      if (i != null && i.esTarjeta) return p.tarjeta(i.id)?.preArribo.isNotEmpty ?? false;
      return o.destino != null && p.nodos.containsKey(o.destino);
    }).toList();

    return PopScope(
      canPop: _historial.length == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _historial.removeLast());
      },
      child: Pantalla(
        titulo: grupo.nombre,
        cuerpo: Column(children: [
          const FranjaReflectiva(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Cuerpo(
                key: ValueKey(_historial.last),
                hijos: [
                  for (final l in nodo.lineas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.m),
                      child: Text(l, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.25)),
                    ),
                  const SizedBox(height: Space.m),
                  for (final o in opciones)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.s),
                      child: o.volver
                          ? TextButton.icon(
                              onPressed: () => _ir(o, p),
                              icon: const PhosphorIcon(PhosphorIconsBold.arrowLeft),
                              label: Text(o.texto),
                            )
                          : FilledButton(
                              style: Estilos.oscuro().copyWith(minimumSize: const WidgetStatePropertyAll(Size(64, Sizes.primaryButton))),
                              onPressed: () => _ir(o, p),
                              child: Text(o.texto, textAlign: TextAlign.center),
                            ),
                    ),
                  if (opciones.isEmpty)
                    Text('Fin de este paso. Si algo cambia, llame al 119.', style: t.bodyMedium),
                ],
              ),
            ),
          ),
        ]),
        abajo: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, Space.m),
            decoration: const BoxDecoration(color: Palette.ceniza, border: Border(top: BorderSide(color: Palette.arenaOscura))),
            child: FilledButton.icon(
              style: Estilos.emergencia(),
              onPressed: () => Enlaces.llamar(AppConfig.lineaEmergencia),
              icon: const PhosphorIcon(PhosphorIconsFill.phone),
              label: const Text('LLAMAR AL 119'),
            ),
          ),
        ),
      ),
    );
  }
}
