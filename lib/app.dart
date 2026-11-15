import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'core/widgets/estados.dart';
import 'core/widgets/marca.dart';
import 'features/auth/auth_service.dart';
import 'features/ciudadano/ciudadano_shell.dart';
import 'features/ciudadano/detalle_reporte_screen.dart';
import 'features/operador/operador_shell.dart';

class App extends StatelessWidget {
  const App({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Al tocar una notificacion local: abre el reporte (o la llamada).
  static void alTocarNotificacion(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final id = payload.startsWith('llamada:') ? payload.substring(8) : payload;
    navigatorKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => DetalleReporteScreen(radicado: id)));
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Bomberos Cali',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.light(),
        locale: const Locale('es', 'CO'),
        supportedLocales: const [Locale('es', 'CO'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const _Puerta(),
      );
}

/// Decide la pantalla segun la sesion y el rol guardado en Firestore.
class _Puerta extends StatelessWidget {
  const _Puerta();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.usuario == null && auth.errorInicio != null) {
      return Scaffold(
        body: SafeArea(
          child: VistaMensaje(
            icono: PhosphorIconsBold.wifiSlash,
            titulo: 'No pudimos iniciar',
            mensaje: '${mensajeAuth(auth.errorInicio!)}\n\nSi es una emergencia, llame al 119.',
            accion: auth.reintentarSesion,
          ),
        ),
      );
    }
    if (!auth.listo || auth.usuario == null) return const _PantallaCarga();
    return auth.esOperador ? const OperadorShell() : const CiudadanoShell();
  }
}

class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Palette.ceniza,
        body: Center(child: BrandMark(size: 96)),
      );
}
