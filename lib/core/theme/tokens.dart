import 'package:flutter/material.dart';

/// Paleta tomada del escudo de los Bomberos Voluntarios de Cali: negro, rojo y
/// amarillo. Los nombres de las constantes vienen de la primera version
/// (brasa = color primario, oxido = rojo oscuro de apoyo) y se conservaron.
/// Contrastes medidos (WCAG) sobre [Palette.ceniza]: carbon 17:1, textoSuave 7:1,
/// brasaOscura 7:1, rojo 5.4:1, verde 5.6:1. El amarillo [Palette.brasa] se usa
/// siempre con texto carbon (12:1); el rojo con texto blanco (5.9:1).
abstract final class Palette {
  static const ceniza = Color(0xFFF8F6F1);
  static const arena = Color(0xFFEEEAE1);
  static const arenaOscura = Color(0xFFD9D3C5);
  static const carbon = Color(0xFF121212);
  static const textoSuave = Color(0xFF55504A);

  /// Amarillo del escudo. Color primario de botones e indicadores.
  static const brasa = Color(0xFFFFC20E);

  /// Rojo oscuro para texto de acento sobre fondo claro.
  static const brasaOscura = Color(0xFFA8101C);
  static const oxido = Color(0xFF8C1017);

  /// Rojo del escudo: solo acciones de emergencia y urgencias.
  static const rojo = Color(0xFFC8102E);
  static const ambar = Color(0xFFFFC20E);
  static const verde = Color(0xFF2F6B3A);
  static const verdeSuave = Color(0xFFD5E4D2);
  static const ambarSuave = Color(0xFFFFF0B3);
  static const rojoSuave = Color(0xFFF7D4D8);
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
  /// Sombras tintadas con negro, bajas y cortas.
  static const card = [
    BoxShadow(color: Color(0x1A121212), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x26121212), blurRadius: 14, offset: Offset(0, 6)),
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
