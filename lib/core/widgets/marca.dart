import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Llama del emblema. Mismas curvas que tools/gen_brand.py (cuadro de 100x100).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.color = Palette.rojo, this.inner = Palette.ambar});

  final double size;
  final Color color;
  final Color inner;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _FlamePainter(color, inner));
}

class _FlamePainter extends CustomPainter {
  _FlamePainter(this.color, this.inner);
  final Color color;
  final Color inner;

  Path _path(List<List<double>> segs, double k) {
    final p = Path()..moveTo(segs.first[0] * k, segs.first[1] * k);
    for (final s in segs) {
      p.cubicTo(s[2] * k, s[3] * k, s[4] * k, s[5] * k, s[6] * k, s[7] * k);
    }
    return p..close();
  }

  // Cada fila: x0,y0, c1x,c1y, c2x,c2y, x3,y3
  static const _outer = [
    [50.0, 10.0, 62.0, 28.0, 82.0, 42.0, 82.0, 64.0],
    [82.0, 64.0, 82.0, 80.0, 68.0, 92.0, 50.0, 92.0],
    [50.0, 92.0, 32.0, 92.0, 18.0, 80.0, 18.0, 64.0],
    [18.0, 64.0, 18.0, 52.0, 26.0, 44.0, 32.0, 36.0],
    [32.0, 36.0, 34.0, 46.0, 40.0, 50.0, 44.0, 50.0],
    [44.0, 50.0, 42.0, 36.0, 44.0, 22.0, 50.0, 10.0],
  ];
  static const _inner = [
    [50.0, 56.0, 58.0, 64.0, 66.0, 70.0, 66.0, 78.0],
    [66.0, 78.0, 66.0, 86.0, 58.0, 90.0, 50.0, 90.0],
    [50.0, 90.0, 42.0, 90.0, 34.0, 86.0, 34.0, 78.0],
    [34.0, 78.0, 34.0, 70.0, 44.0, 66.0, 50.0, 56.0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100;
    canvas.drawPath(_path(_outer, k), Paint()..color = color);
    canvas.drawPath(_path(_inner, k), Paint()..color = inner);
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.color != color || old.inner != inner;
}

/// Franjas diagonales como las cintas reflectivas de la parte trasera de una
/// maquina. Se usa en pocos sitios: cabecera de inicio, confirmacion y errores
/// graves. Es decorativa, por eso queda fuera del arbol de accesibilidad.
class FranjaReflectiva extends StatelessWidget {
  const FranjaReflectiva({
    super.key,
    this.height = 10,
    this.colorA = Palette.brasa,
    this.colorB = Palette.carbon,
  });

  final double height;
  final Color colorA;
  final Color colorB;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _StripePainter(colorA, colorB)),
        ),
      );
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.a, this.b);
  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = b);
    final w = size.height * 1.6;
    final paint = Paint()..color = a;
    for (double x = -size.height; x < size.width + size.height; x += w * 2) {
      final p = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + w, size.height)
        ..lineTo(x + w + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.a != a || old.b != b;
}

/// Separador con forma de manguera: linea gruesa con acoples en los extremos.
class SeparadorManguera extends StatelessWidget {
  const SeparadorManguera({super.key, this.vertical = Space.l});

  final double vertical;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: vertical),
          child: SizedBox(height: 12, width: double.infinity, child: CustomPaint(painter: _HosePainter())),
        ),
      );
}

class _HosePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final hose = Paint()
      ..color = Palette.arenaOscura
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(10, cy), Offset(size.width - 10, cy), hose);
    final coupling = Paint()..color = Palette.oxido;
    for (final x in [0.0, size.width - 10]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, cy - 6, 10, 12), const Radius.circular(2)),
        coupling,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Sello de la app en las cabeceras: llama y nombre en tipografia de rotulo.
class Sello extends StatelessWidget {
  const Sello({super.key, this.claro = true});
  final bool claro;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const BrandMark(size: 30, color: Palette.rojo, inner: Palette.ambar),
      const SizedBox(width: Space.s),
      Text('BOMBEROS CALI',
          style: t.titleLarge?.copyWith(letterSpacing: 1.2, color: claro ? Palette.ceniza : Palette.carbon)),
    ]);
  }
}
