import 'package:flutter/material.dart';

/// Paleta. Contrastes medidos (WCAG) sobre [Palette.ceniza]:
/// carbon 15.1:1, textoSuave 6.8:1, brasaOscura 4.8:1, rojo 5.7:1, verde 5.6:1.
/// El naranja brasa (#E8590C) no alcanza AA con texto blanco (3.6:1), por eso
/// los botones primarios llevan texto carbon (4.8:1).
abstract final class Palette {
  static const ceniza = Color(0xFFF6EFE7);
  static const arena = Color(0xFFEDE1D3);
  static const arenaOscura = Color(0xFFDCCBB8);
  static const carbon = Color(0xFF1F1A17);
  static const textoSuave = Color(0xFF5C5048);

  static const brasa = Color(0xFFE8590C);
  static const brasaOscura = Color(0xFFB8430A);
  static const oxido = Color(0xFF8A3B12);
  static const rojo = Color(0xFFB3261E);
  static const ambar = Color(0xFFF2A33A);
  static const verde = Color(0xFF2F6B3A);
  static const verdeSuave = Color(0xFFD5E4D2);
  static const ambarSuave = Color(0xFFFAE3BE);
  static const rojoSuave = Color(0xFFF3D3CF);
}

abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double gutter = 20;
}

abstract final class Radii {
  static const double s = 6;
  static const double m = 10;
  static const double l = 16;
  static const double sheet = 20;
  static BorderRadius get card => BorderRadius.circular(m);
  static BorderRadius get control => BorderRadius.circular(m);
  static BorderRadius get chip => BorderRadius.circular(s);
}

abstract final class Elevations {
  /// Sombras tintadas con carbon, bajas y cortas.
  static const card = [
    BoxShadow(color: Color(0x1A1F1A17), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x261F1A17), blurRadius: 14, offset: Offset(0, 6)),
  ];
}

abstract final class Sizes {
  /// Alto minimo de cualquier area tactil.
  static const double touch = 48;
  static const double primaryButton = 56;
  static const double border = 1.5;
}

abstract final class Fonts {
  static const display = 'BarlowCondensed';
  static const body = 'Barlow';
}
