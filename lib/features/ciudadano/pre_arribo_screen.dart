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
import 'procedimiento_screen.dart';

/// Instrucciones pre-arribo de la tarjeta, tal como estan en el protocolo,
/// con letra grande y un bloque por indicacion para leerlas bajo estres.
class PreArriboScreen extends StatefulWidget {
  const PreArriboScreen({super.key, required this.tarjeta, this.radicado});

  final Tarjeta tarjeta;
  final String? radicado;

  @override
  State<PreArriboScreen> createState() => _PreArriboScreenState();
}

class _PreArriboScreenState extends State<PreArriboScreen> {
  /// Pila de secciones visitadas (indices en `tarjeta.preArribo`).
  final List<int> _pila = [0];

  SeccionPreArribo get _seccion => widget.tarjeta.preArribo[_pila.last];

  void _abrir(Referencia r) {
    final d = r.destino;
    if (d == null) return;
    // Otra diapositiva de la misma tarjeta: se cambia de seccion.
    final i = widget.tarjeta.preArribo.indexWhere((s) => s.diapositiva == r.diapositiva);
    if (i >= 0) {
      setState(() => _pila.add(i));
      return;
    }
    final protocolo = context.read<Protocolo>();
    if (d.esTarjeta) {
      final otra = protocolo.tarjeta(d.id);
      if (otra != null && otra.preArribo.isNotEmpty) {
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PreArriboScreen(tarjeta: otra)));
      }
    } else if (d.esProcedimiento) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ProcedimientoScreen(grupoId: d.grupo!, nodoInicial: d.nodo!),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = _seccion;
    final protocolo = context.read<Protocolo>();
    // Solo se muestran enlaces con destino dentro de la app.
    final refs = s.referencias.where((r) {
      final d = r.destino;
      if (d == null) return false;
      if (d.esProcedimiento) return protocolo.nodos.containsKey(d.nodo);
      if (d.esTarjeta) return protocolo.tarjeta(d.id)?.preArribo.isNotEmpty ?? false;
      return false;
    }).toList();

    return PopScope(
      canPop: _pila.length == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _pila.removeLast());
      },
      child: Pantalla(
        titulo: 'Instrucciones',
        cuerpo: Column(children: [
          const FranjaReflectiva(),
          Expanded(
            child: Cuerpo(hijos: [
              Text('MIENTRAS LLEGAN LOS BOMBEROS', style: t.titleLarge?.copyWith(color: Palette.oxido, letterSpacing: 1)),
              const SizedBox(height: Space.xs),
              Text(widget.tarjeta.nombre, style: t.headlineMedium),
              const SizedBox(height: Space.l),
              for (final l in s.lineas) _Linea(texto: l),
              if (refs.isNotEmpty) ...[
                const SizedBox(height: Space.m),
                for (final r in refs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.s),
                    child: OutlinedButton.icon(
                      onPressed: () => _abrir(r),
                      icon: const PhosphorIcon(PhosphorIconsBold.arrowRight),
                      label: Text(r.texto, textAlign: TextAlign.center),
                    ),
                  ),
              ],
              if (_pila.length > 1) ...[
                const SizedBox(height: Space.s),
                TextButton.icon(
                  onPressed: () => setState(() => _pila.removeLast()),
                  icon: const PhosphorIcon(PhosphorIconsBold.arrowLeft),
                  label: const Text('Volver'),
                ),
              ],
            ]),
          ),
        ]),
        abajo: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, Space.m),
            decoration: const BoxDecoration(
              color: Palette.ceniza,
              border: Border(top: BorderSide(color: Palette.arenaOscura)),
            ),
            child: FilledButton.icon(
              style: Estilos.emergencia(),
              onPressed: () => Enlaces.llamar(AppConfig.lineaEmergencia),
              icon: const PhosphorIcon(PhosphorIconsFill.phone),
              label: const Text('SI CAMBIA ALGO, LLAME AL 119'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Una indicacion del protocolo. Los encabezados ("Si es por calor:",
/// "TÉRMICA") se distinguen de las instrucciones solo por formato.
class _Linea extends StatelessWidget {
  const _Linea({required this.texto});
  final String texto;

  static bool _esEncabezado(String s) {
    final limpio = s.trim();
    if (limpio.length > 60) return false;
    final letras = limpio.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÑáéíóúñ]'), '');
    final mayus = letras.isNotEmpty && letras == letras.toUpperCase();
    return limpio.endsWith(':') || (mayus && letras.length >= 4);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (_esEncabezado(texto)) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.m, bottom: Space.s),
        child: Text(texto, style: t.titleLarge?.copyWith(color: Palette.oxido)),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: Space.s),
      padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.m, Space.m),
      decoration: const BoxDecoration(
        color: Palette.arena,
        border: Border(left: BorderSide(color: Palette.brasa, width: 5)),
        borderRadius: BorderRadius.only(topRight: Radius.circular(Radii.m), bottomRight: Radius.circular(Radii.m)),
      ),
      child: Text(texto, style: t.bodyLarge?.copyWith(fontSize: 20, height: 1.38)),
    );
  }
}
