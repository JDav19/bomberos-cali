import 'dart:math';

import 'package:bomberos_cali/core/theme/tokens.dart';
import 'package:bomberos_cali/features/reportes/models.dart';
import 'package:bomberos_cali/features/reportes/prioridad.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

double _lum(Color c) {
  double f(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _contraste(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  final protocolo = protocoloDeDisco();

  group('Reporte rapido', () {
    test('solo con foto y ubicacion se considera rapido', () {
      final r = reporteDe(categoria: '900', tarjetaId: null);
      expect(r.esRapido, isTrue);
      expect(r.copyWith(descripcion: 'Humo en el segundo piso').esRapido, isFalse);
      expect(r.copyWith(referencia: 'Frente al parque').esRapido, isFalse);
    });

    test('la categoria 900 existe en el protocolo y arranca con prioridad media', () {
      expect(protocolo.categoria('900'), isNotNull);
      expect(prioridadBase('900', null), Prioridad.media);
    });

    test('completar detalles cambia el tipo y conserva ubicacion, estado y radicado', () {
      final r = reporteDe(categoria: '900', tarjetaId: null, prioridad: Prioridad.media);
      final nuevo = r.copyWith(
        categoria: '100',
        categoriaNombre: 'Incendios',
        tarjetaId: 'incendio_edificio_alto',
        tarjetaNombre: 'Incendio en edificio alto',
        nombre: 'Luis',
        telefono: '3109998877',
      );
      expect(nuevo.categoria, '100');
      expect(nuevo.tarjetaId, 'incendio_edificio_alto');
      expect(nuevo.nombre, 'Luis');
      expect(nuevo.radicado, r.radicado);
      expect(nuevo.ubicacion!.lat, r.ubicacion!.lat);
      expect(nuevo.estado, r.estado);
      expect(nuevo.esRapido, isFalse);
    });

    test('sinTarjeta quita la tarjeta anterior al cambiar de categoria', () {
      final r = reporteDe(categoria: '300', tarjetaId: 'trauma');
      final nuevo = r.copyWith(categoria: '900', categoriaNombre: 'Otro', sinTarjeta: true);
      expect(nuevo.tarjetaId, isNull);
      expect(nuevo.tarjetaNombre, isNull);
    });

    test('el tipo exacto sube la prioridad del reporte rapido', () {
      expect(prioridadBase('100', 'incendio_edificio_alto'), Prioridad.critica);
      expect(prioridadBase('100', 'incendio_edificio_alto').peso, lessThan(Prioridad.media.peso));
    });
  });

  group('Paleta del escudo (WCAG)', () {
    test('texto principal y suave sobre el fondo cumplen AA', () {
      expect(_contraste(Palette.carbon, Palette.ceniza), greaterThanOrEqualTo(7));
      expect(_contraste(Palette.textoSuave, Palette.ceniza), greaterThanOrEqualTo(4.5));
      expect(_contraste(Palette.textoSuave, Palette.arena), greaterThanOrEqualTo(4.5));
    });

    test('botones: texto negro sobre amarillo y blanco sobre rojo', () {
      expect(_contraste(Palette.carbon, Palette.brasa), greaterThanOrEqualTo(7));
      expect(_contraste(const Color(0xFFFFFFFF), Palette.rojo), greaterThanOrEqualTo(4.5));
    });

    test('el rojo y el rojo oscuro de acento se leen sobre el fondo claro', () {
      expect(_contraste(Palette.rojo, Palette.ceniza), greaterThanOrEqualTo(4.5));
      expect(_contraste(Palette.brasaOscura, Palette.ceniza), greaterThanOrEqualTo(4.5));
      expect(_contraste(Palette.oxido, Palette.arena), greaterThanOrEqualTo(4.5));
    });

    test('la barra superior negra mantiene legible el texto claro y el acento amarillo', () {
      expect(_contraste(Palette.ceniza, Palette.carbon), greaterThanOrEqualTo(7));
      expect(_contraste(Palette.ambar, Palette.carbon), greaterThanOrEqualTo(7));
    });
  });
}
