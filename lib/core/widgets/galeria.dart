import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';

import '../../features/reportes/models.dart';
import '../theme/tokens.dart';
import '../util/servicios_dispositivo.dart';

/// Cuadricula de fotos y videos de un reporte. Al tocar abre el visor.
class GaleriaMedia extends StatelessWidget {
  const GaleriaMedia({super.key, required this.items, this.pendientes = 0});

  final List<MediaItem> items;
  final int pendientes;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (items.isEmpty && pendientes == 0) {
      return Text('Este reporte no tiene fotos ni videos.', style: t.bodyMedium);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: Space.s, crossAxisSpacing: Space.s),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final m = items[i];
          return Semantics(
            button: true,
            label: '${m.tipo == TipoMedia.foto ? 'Foto' : 'Video'} ${i + 1} de ${items.length}',
            child: InkWell(
              borderRadius: Radii.card,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => VisorMedia(items: items, inicial: i),
              )),
              child: ClipRRect(
                borderRadius: Radii.card,
                child: Stack(fit: StackFit.expand, children: [
                  Container(color: Palette.arenaOscura),
                  Image.network(
                    m.miniatura,
                    fit: BoxFit.cover,
                    cacheWidth: 360,
                    loadingBuilder: (_, child, p) => p == null ? child : const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))),
                    errorBuilder: (_, _, _) => const Center(child: PhosphorIcon(PhosphorIconsBold.imageBroken, color: Palette.textoSuave)),
                  ),
                  if (m.tipo == TipoMedia.video)
                    const Center(
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Palette.carbon,
                        child: PhosphorIcon(PhosphorIconsFill.play, color: Palette.ceniza, size: 20),
                      ),
                    ),
                ]),
              ),
            ),
          );
        },
      ),
      if (pendientes > 0) ...[
        const SizedBox(height: Space.s),
        Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: Space.s),
          Expanded(child: Text('Faltan $pendientes ${pendientes == 1 ? 'archivo' : 'archivos'} por llegar.', style: t.bodyMedium)),
        ]),
      ],
    ]);
  }
}

class VisorMedia extends StatefulWidget {
  const VisorMedia({super.key, required this.items, required this.inicial});

  final List<MediaItem> items;
  final int inicial;

  @override
  State<VisorMedia> createState() => _VisorMediaState();
}

class _VisorMediaState extends State<VisorMedia> {
  late final PageController _c = PageController(initialPage: widget.inicial);
  late int _i = widget.inicial;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Palette.carbon,
      appBar: AppBar(
        backgroundColor: Palette.carbon,
        foregroundColor: Palette.ceniza,
        title: Text('${_i + 1} de ${widget.items.length}', style: t.titleLarge?.copyWith(color: Palette.ceniza)),
        shape: const Border(),
      ),
      body: PageView.builder(
        controller: _c,
        itemCount: widget.items.length,
        onPageChanged: (v) => setState(() => _i = v),
        itemBuilder: (context, i) {
          final m = widget.items[i];
          if (m.tipo == TipoMedia.video) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.network(m.miniatura, height: 260, errorBuilder: (_, _, _) => const SizedBox.shrink()),
                const SizedBox(height: Space.xl),
                FilledButton.icon(
                  onPressed: () => Enlaces.url(m.url),
                  icon: const PhosphorIcon(PhosphorIconsFill.play),
                  label: const Text('REPRODUCIR VIDEO'),
                ),
              ]),
            );
          }
          return InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Image.network(
                m.url.replaceFirst('/upload/', '/upload/c_limit,w_1600,q_auto/'),
                fit: BoxFit.contain,
                loadingBuilder: (_, child, p) => p == null ? child : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, _, _) => const Center(child: PhosphorIcon(PhosphorIconsBold.imageBroken, color: Palette.ceniza, size: 48)),
              ),
            ),
          );
        },
      ),
    );
  }
}
