import 'package:bomberos_cali/core/util/geo.dart';
import 'package:bomberos_cali/features/reportes/agrupacion.dart';
import 'package:bomberos_cali/features/reportes/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 19, 15);

  test('distancia de haversine: 0,001 grados de latitud son unos 111 m', () {
    final d = distanciaMetros(3.45, -76.53, 3.451, -76.53);
    expect(d, closeTo(111.2, 1));
  });

  test('enlace de Google Maps con las coordenadas exactas', () {
    expect(enlaceGoogleMaps(3.45161, -76.53201).toString(),
        'https://www.google.com/maps/search/?api=1&query=3.45161,-76.53201');
  });

  test('reportes cercanos y seguidos forman un posible mismo incidente', () {
    final g = agruparReportes([
      reporteDe(radicado: 'A', lat: 3.4516, lng: -76.5320, en: t0),
      reporteDe(radicado: 'B', lat: 3.4520, lng: -76.5322, en: t0.add(const Duration(minutes: 3))),
      reporteDe(radicado: 'C', lat: 3.4518, lng: -76.5318, en: t0.add(const Duration(minutes: 9))),
    ]);
    expect(g, hasLength(1));
    expect(g.single.esPosibleIncidente, isTrue);
    expect(g.single.reportes, hasLength(3));
  });

  test('lejos (mas de 150 m) no se agrupa aunque sea al mismo tiempo', () {
    final g = agruparReportes([
      reporteDe(radicado: 'A', lat: 3.4516, lng: -76.5320, en: t0),
      reporteDe(radicado: 'B', lat: 3.4540, lng: -76.5320, en: t0), // ~267 m
    ]);
    expect(g, hasLength(2));
    expect(g.any((x) => x.esPosibleIncidente), isFalse);
  });

  test('cerca pero separados por mas de 15 minutos no se agrupa', () {
    final g = agruparReportes([
      reporteDe(radicado: 'A', en: t0),
      reporteDe(radicado: 'B', en: t0.add(const Duration(minutes: 16))),
    ]);
    expect(g, hasLength(2));
  });

  test('justo en el umbral entra, justo despues no', () {
    // 0,00134 grados de latitud ~ 149 m ; 0,00136 ~ 151 m
    final dentro = agruparReportes([
      reporteDe(radicado: 'A', lat: 3.4500, lng: -76.5300, en: t0),
      reporteDe(radicado: 'B', lat: 3.45134, lng: -76.5300, en: t0.add(const Duration(minutes: 15))),
    ]);
    expect(dentro, hasLength(1));
    final fuera = agruparReportes([
      reporteDe(radicado: 'A', lat: 3.4500, lng: -76.5300, en: t0),
      reporteDe(radicado: 'B', lat: 3.45136, lng: -76.5300, en: t0.add(const Duration(minutes: 16))),
    ]);
    expect(fuera, hasLength(2));
  });

  test('la relacion es transitiva: una cadena de reportes forma un grupo', () {
    final g = agruparReportes([
      for (var i = 0; i < 4; i++)
        reporteDe(radicado: 'R$i', lat: 3.4500 + i * 0.0012, lng: -76.5300, en: t0.add(Duration(minutes: i * 2))),
    ]);
    expect(g, hasLength(1));
    expect(g.single.reportes, hasLength(4));
  });

  test('un reporte sin ubicacion queda solo', () {
    final g = agruparReportes([
      reporteDe(radicado: 'A', en: t0),
      reporteDe(radicado: 'B', lat: null, en: t0),
    ]);
    expect(g, hasLength(2));
  });

  test('la prioridad del grupo es la mas urgente de sus reportes', () {
    final g = agruparReportes([
      reporteDe(radicado: 'A', en: t0, prioridad: Prioridad.baja),
      reporteDe(radicado: 'B', en: t0, prioridad: Prioridad.critica),
    ]).single;
    expect(g.prioridad, Prioridad.critica);
    expect(g.centro, isNotNull);
  });

  test('con 3.000 reportes dispersos agrupa rapido (malla, no todos contra todos)', () {
    final rs = [
      for (var i = 0; i < 3000; i++)
        reporteDe(
          radicado: 'R$i',
          lat: 3.30 + (i % 60) * 0.004,
          lng: -76.60 + (i ~/ 60) * 0.004,
          en: t0.add(Duration(seconds: i)),
        )
    ];
    final sw = Stopwatch()..start();
    final g = agruparReportes(rs);
    sw.stop();
    expect(g.fold<int>(0, (a, x) => a + x.reportes.length), 3000);
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });
}
