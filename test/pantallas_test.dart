import 'package:bomberos_cali/app.dart' show App;
import 'package:bomberos_cali/core/theme/app_theme.dart';
import 'package:bomberos_cali/core/util/servicios_dispositivo.dart';
import 'package:bomberos_cali/features/ciudadano/pre_arribo_screen.dart';
import 'package:bomberos_cali/features/ciudadano/procedimiento_screen.dart';
import 'package:bomberos_cali/features/ciudadano/tipo_emergencia_screen.dart';
import 'package:bomberos_cali/features/ciudadano/hoja_recomendaciones.dart';
import 'package:bomberos_cali/features/operador/bandeja_screen.dart';
import 'package:bomberos_cali/features/protocolo/protocolo.dart';
import 'package:bomberos_cali/features/reportes/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

/// Pruebas de humo de la interfaz: cada pantalla se dibuja en un telefono de
/// 360 x 800 con el tamano de fuente normal y con el doble, y no debe lanzar
/// excepciones (por ejemplo desbordes de pantalla).
void main() {
  final protocolo = protocoloDeDisco();

  Widget envolver(Widget hijo, double escala) => MultiProvider(
        providers: [
          Provider<Protocolo>.value(value: protocolo),
          ChangeNotifierProvider<ConexionService>(create: (_) => ConexionService()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          navigatorKey: App.navigatorKey,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: hijo,
        ),
      );

  Future<void> dibujar(WidgetTester t, Widget w, double escala) async {
    t.view.physicalSize = const Size(360 * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(envolver(w, escala));
    await t.pump(const Duration(milliseconds: 500));
  }

  for (final escala in [1.0, 2.0]) {
    group('texto x$escala', () {
      testWidgets('tipo de emergencia muestra las siete categorias', (t) async {
        await dibujar(t, const TipoEmergenciaScreen(), escala);
        expect(find.text('Incendio'), findsOneWidget);
        expect(find.text('119'), findsOneWidget, reason: 'el 119 siempre visible');
      });

      testWidgets('instrucciones pre-arribo de accidente de transito', (t) async {
        await dibujar(t, PreArriboScreen(tarjeta: protocolo.tarjeta('accidente_transito')!), escala);
        expect(find.textContaining('MIENTRAS LLEGAN'), findsOneWidget);
        expect(find.textContaining('ni siquiera agua'), findsOneWidget);
        expect(find.text('119'), findsOneWidget);
      });

      testWidgets('pre-arribo de edificio alto con varias secciones', (t) async {
        await dibujar(t, PreArriboScreen(tarjeta: protocolo.tarjeta('incendio_edificio_alto')!), escala);
        expect(find.textContaining('Dentro de la edificación'), findsWidgets);
      });

      testWidgets('RCP adulto: primer nodo y navegacion SI', (t) async {
        final g = protocolo.grupos['rcp_adulto']!;
        await dibujar(t, ProcedimientoScreen(grupoId: g.id, nodoInicial: g.entrada), escala);
        expect(find.text('¿Alguien en el sitio sabe dar RCP?'), findsOneWidget);
        await t.ensureVisible(find.text('SI'));
        await t.tap(find.text('SI'));
        await t.pumpAndSettle();
        expect(find.textContaining('Necesita ayuda para recordarle'), findsOneWidget);
        await t.ensureVisible(find.text('NO'));
        await t.tap(find.text('NO'));
        await t.pumpAndSettle();
        expect(find.textContaining('Inicie RCP en el paciente ahora'), findsOneWidget);
      });

      testWidgets('hoja de recomendaciones de fotos', (t) async {
        await dibujar(
          t,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(onPressed: () => mostrarHojaRecomendaciones(context), child: const Text('abrir')),
              ),
            ),
          ),
          escala,
        );
        await t.tap(find.text('abrir'));
        await t.pumpAndSettle();
        expect(find.textContaining('Primero, una foto general'), findsOneWidget);
        expect(find.textContaining('No se arriesgue'), findsOneWidget);
        expect(find.text('TOMAR FOTO'), findsOneWidget);
      });

      testWidgets('tarjeta de reporte del operador', (t) async {
        await dibujar(
          t,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TarjetaReporteOperador(
                reporte: reporteDe(prioridad: Prioridad.critica).copyWith(mediaPendiente: 2),
              ),
            ),
          ),
          escala,
        );
        expect(find.text('CRÍTICA'), findsOneWidget);
        expect(find.text('Recibido'), findsOneWidget);
      });
    });
  }
}
