import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/estados.dart';
import '../../core/widgets/marca.dart';
import '../auth/auth_service.dart';
import '../reportes/reportes_repository.dart';
import 'bandeja_screen.dart';
import 'mapa_operador_screen.dart';
import 'operador_controller.dart';

class OperadorShell extends StatelessWidget {
  const OperadorShell({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<OperadorController>(
        create: (c) => OperadorController(repo: c.read<ReportesRepository>(), auth: c.read<AuthService>()),
        child: const _Vista(),
      );
}

class _Vista extends StatefulWidget {
  const _Vista();

  @override
  State<_Vista> createState() => _VistaState();
}

class _VistaState extends State<_Vista> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<OperadorController>();
    final activos = ctrl.activos.length;
    return Scaffold(
      appBar: AppBar(
        title: const Sello(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Space.l),
            child: Center(
              child: Text('RADIO OPERADOR',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Palette.oxido, letterSpacing: 1)),
            ),
          ),
        ],
      ),
      body: Column(children: [
        const AvisoSinConexion(),
        Expanded(
          child: IndexedStack(index: _i, children: const [BandejaScreen(), MapaOperadorScreen(), _CuentaOperador()]),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activos > 0,
              label: Text('$activos'),
              backgroundColor: Palette.rojo,
              child: const PhosphorIcon(PhosphorIconsBold.tray),
            ),
            label: 'Bandeja',
          ),
          const NavigationDestination(icon: PhosphorIcon(PhosphorIconsBold.mapTrifold), label: 'Mapa'),
          const NavigationDestination(icon: PhosphorIcon(PhosphorIconsBold.userCircle), label: 'Cuenta'),
        ],
      ),
    );
  }
}

class _CuentaOperador extends StatelessWidget {
  const _CuentaOperador();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.watch<AuthService>().perfil;
    return Cuerpo(hijos: [
      Row(children: [
        const PhosphorIcon(PhosphorIconsBold.headset, size: 44, color: Palette.oxido),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p?.nombre.isNotEmpty == true ? p!.nombre : 'Radio operador', style: t.titleLarge),
            Text(p?.correo ?? '', style: t.bodyMedium),
          ]),
        ),
      ]),
      const SizedBox(height: Space.xl),
      OutlinedButton(onPressed: () => context.read<AuthService>().salir(), child: const Text('Cerrar sesión')),
    ]);
  }
}
