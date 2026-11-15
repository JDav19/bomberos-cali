import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/estados.dart';
import '../../core/widgets/marca.dart';
import '../reportes/mis_reportes.dart';
import '../videollamada/llamada_entrante_screen.dart';
import 'cuenta_screen.dart';
import 'inicio_screen.dart';
import 'mis_reportes_screen.dart';

class CiudadanoShell extends StatefulWidget {
  const CiudadanoShell({super.key});

  @override
  State<CiudadanoShell> createState() => _CiudadanoShellState();
}

class _CiudadanoShellState extends State<CiudadanoShell> {
  int _i = 0;
  bool _mostrandoLlamada = false;

  void _revisarLlamada(BuildContext context) {
    final r = context.read<MisReportes>().llamadaEntrante;
    if (r == null || _mostrandoLlamada) return;
    _mostrandoLlamada = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => LlamadaEntranteScreen(radicado: r.radicado),
      ));
      _mostrandoLlamada = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Se observa para reaccionar cuando llega una videollamada.
    context.select<MisReportes, String?>((m) => m.llamadaEntrante?.radicado);
    _revisarLlamada(context);

    const titulos = ['', 'Mis reportes', 'Mi cuenta'];
    return Scaffold(
      appBar: AppBar(
        title: _i == 0 ? const Sello() : Text(titulos[_i]),
        actions: const [Boton119()],
      ),
      body: Column(children: [
        const AvisoSinConexion(),
        Expanded(
          child: IndexedStack(index: _i, children: const [InicioScreen(), MisReportesScreen(), CuentaScreen()]),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: PhosphorIcon(PhosphorIconsBold.house), label: 'Inicio'),
          NavigationDestination(icon: PhosphorIcon(PhosphorIconsBold.listChecks), label: 'Mis reportes'),
          NavigationDestination(icon: PhosphorIcon(PhosphorIconsBold.userCircle), label: 'Mi cuenta'),
        ],
      ),
    );
  }
}

/// Reservado para animaciones de entrada del contenido principal.
class Aparece extends StatelessWidget {
  const Aparece({super.key, required this.child, this.retardo = Duration.zero});
  final Widget child;
  final Duration retardo;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320) + retardo,
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: c),
      ),
      child: child,
    );
  }
}

const separadorM = SizedBox(height: Space.m);
