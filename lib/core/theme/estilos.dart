import 'package:flutter/material.dart';

import 'tokens.dart';

/// Estilos de boton fuera del tema base. El rojo se reserva para la accion de
/// emergencia (reportar, llamar al 119, finalizar una llamada).
abstract final class Estilos {
  static ButtonStyle emergencia({double alto = Sizes.primaryButton}) => FilledButton.styleFrom(
        backgroundColor: Palette.rojo,
        foregroundColor: Colors.white,
        minimumSize: Size(64, alto),
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        shape: RoundedRectangleBorder(borderRadius: Radii.control),
        textStyle: const TextStyle(
            fontFamily: Fonts.display, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 0.6),
      );

  static ButtonStyle oscuro() => FilledButton.styleFrom(
        backgroundColor: Palette.carbon,
        foregroundColor: Palette.ceniza,
        minimumSize: const Size(64, Sizes.touch),
        shape: RoundedRectangleBorder(borderRadius: Radii.control),
        textStyle: const TextStyle(
            fontFamily: Fonts.display, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      );
}
