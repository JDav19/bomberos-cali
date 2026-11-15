import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/marca.dart';

/// Se muestra cuando la app se compilo sin las claves de Firebase. Dice
/// exactamente que falta, en vez de fallar con una pantalla en blanco.
class ConfiguracionPendienteApp extends StatelessWidget {
  const ConfiguracionPendienteApp({super.key, required this.faltantes});

  final List<String> faltantes;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Bomberos Cali',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(
          body: SafeArea(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const FranjaReflectiva(height: 14),
              Expanded(
                child: Builder(builder: (context) {
                  final t = Theme.of(context).textTheme;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(Space.gutter),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: Space.xl),
                      const Sello(),
                      const SizedBox(height: Space.xxl),
                      Text('Falta configurar la aplicación', style: t.headlineMedium),
                      const SizedBox(height: Space.m),
                      Text(
                          'Esta compilación no tiene las claves de Firebase. Copie config/app_config.example.json a '
                          'config/app_config.json, pegue los valores y compile con:',
                          style: t.bodyLarge),
                      const SizedBox(height: Space.m),
                      Container(
                        padding: const EdgeInsets.all(Space.m),
                        decoration: BoxDecoration(color: Palette.arena, borderRadius: Radii.card),
                        child: Text('flutter run --dart-define-from-file=config/app_config.json',
                            style: t.bodyMedium?.copyWith(fontFamily: 'monospace')),
                      ),
                      const SizedBox(height: Space.xl),
                      Text('VARIABLES SIN VALOR', style: t.labelLarge?.copyWith(color: Palette.oxido, letterSpacing: 1)),
                      const SizedBox(height: Space.s),
                      for (final f in faltantes)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(f, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      const SizedBox(height: Space.xl),
                      Text('Los pasos están en docs/SETUP.md.', style: t.bodyMedium),
                    ]),
                  );
                }),
              ),
            ]),
          ),
        ),
      );
}
