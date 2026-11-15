import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';

import '../../core/theme/tokens.dart';

enum FuenteMedia { foto, video, galeria }

/// Hoja flotante con las recomendaciones para tomar fotos y videos. Aparece
/// siempre antes de abrir la camara, como pide el enunciado.
Future<FuenteMedia?> mostrarHojaRecomendaciones(BuildContext context) =>
    showModalBottomSheet<FuenteMedia>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _Hoja(),
    );

class _Hoja extends StatelessWidget {
  const _Hoja();

  static const _pasos = [
    ('1', 'Primero, una foto general', 'Que se vea todo el lugar: el edificio, la calle, el vehículo.'),
    ('2', 'Después, los detalles', 'Humo, llamas, daños, personas afectadas, placas o letreros.'),
    ('3', 'Manténgase a distancia segura', 'No se acerque al fuego, a cables caídos, al tráfico ni a estructuras dañadas.'),
    ('4', 'No se arriesgue por una foto', 'Su seguridad es primero. Si no puede tomarla sin peligro, no la tome.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.l),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Antes de tomar las fotos', style: t.headlineSmall),
          const SizedBox(height: Space.m),
          for (final p in _pasos)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: Palette.carbon, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(p.$1, style: t.titleLarge?.copyWith(color: Palette.ceniza, height: 1)),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.$2, style: t.titleMedium),
                    Text(p.$3, style: t.bodyMedium),
                  ]),
                ),
              ]),
            ),
          Text('Si graba un video, que sea corto (hasta 1 minuto) y sin moverse mucho.', style: t.bodyMedium),
          const SizedBox(height: Space.l),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, FuenteMedia.foto),
            icon: const PhosphorIcon(PhosphorIconsBold.camera),
            label: const Text('TOMAR FOTO'),
          ),
          const SizedBox(height: Space.s),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, FuenteMedia.video),
            icon: const PhosphorIcon(PhosphorIconsBold.videoCamera),
            label: const Text('Grabar video'),
          ),
          const SizedBox(height: Space.s),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, FuenteMedia.galeria),
            icon: const PhosphorIcon(PhosphorIconsBold.images),
            label: const Text('Elegir de la galería'),
          ),
        ]),
      ),
    );
  }
}
