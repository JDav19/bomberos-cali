import '../../core/util/geo.dart';
import 'models.dart';

/// Umbrales por defecto para considerar que varios reportes son un posible
/// mismo incidente. Justificacion en docs/DECISIONES.md:
/// - 150 m: ~1,5 cuadras. Cubre el error de GPS en calle urbana (10 a 50 m) y
///   que la gente reporte desde puntos distintos de la misma escena.
/// - 15 min: ventana en la que una escena genera la mayoria de sus llamadas.
const radioAgrupacionM = 150.0;
const ventanaAgrupacion = Duration(minutes: 15);

class GrupoReportes {
  GrupoReportes(this.reportes);

  final List<Reporte> reportes;

  bool get esPosibleIncidente => reportes.length > 1;

  Prioridad get prioridad =>
      reportes.map((r) => r.prioridad).reduce((a, b) => a.peso <= b.peso ? a : b);

  DateTime get primero => reportes.map((r) => r.creadoEn).reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime get ultimo => reportes.map((r) => r.creadoEn).reduce((a, b) => a.isAfter(b) ? a : b);

  /// Centro aproximado (promedio de las coordenadas).
  Ubicacion? get centro {
    final u = reportes.map((r) => r.ubicacion).whereType<Ubicacion>().toList();
    if (u.isEmpty) return null;
    return Ubicacion(
      lat: u.map((e) => e.lat).reduce((a, b) => a + b) / u.length,
      lng: u.map((e) => e.lng).reduce((a, b) => a + b) / u.length,
    );
  }
}

/// Agrupa por enlace simple: dos reportes quedan juntos si estan a menos de
/// `radioM` y se crearon con menos de `ventana` de diferencia; la relacion es
/// transitiva. Usa una malla de celdas de `radioM` para no comparar todos con
/// todos cuando hay miles de reportes. Los reportes sin ubicacion quedan solos.
List<GrupoReportes> agruparReportes(
  List<Reporte> reportes, {
  double radioM = radioAgrupacionM,
  Duration ventana = ventanaAgrupacion,
}) {
  final n = reportes.length;
  final padre = List<int>.generate(n, (i) => i);
  int raiz(int x) {
    while (padre[x] != x) {
      padre[x] = padre[padre[x]];
      x = padre[x];
    }
    return x;
  }

  void unir(int a, int b) {
    final ra = raiz(a), rb = raiz(b);
    if (ra != rb) padre[ra] = rb;
  }

  // ~111.320 m por grado de latitud; la longitud se ajusta por el coseno
  // de forma aproximada usando la misma celda (suficiente para Cali).
  const metrosPorGrado = 111320.0;
  final celdaGrados = radioM / metrosPorGrado;
  final malla = <(int, int), List<int>>{};
  (int, int) celda(Ubicacion u) => ((u.lat / celdaGrados).floor(), (u.lng / celdaGrados).floor());

  for (var i = 0; i < n; i++) {
    final u = reportes[i].ubicacion;
    if (u == null) continue;
    malla.putIfAbsent(celda(u), () => []).add(i);
  }

  for (var i = 0; i < n; i++) {
    final u = reportes[i].ubicacion;
    if (u == null) continue;
    final (cy, cx) = celda(u);
    // La longitud pierde metros por grado lejos del ecuador; con el 3 de
    // margen (3 celdas) se cubre hasta ~70 grados de latitud.
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -3; dx <= 3; dx++) {
        for (final j in malla[(cy + dy, cx + dx)] ?? const <int>[]) {
          if (j <= i) continue;
          final v = reportes[j].ubicacion!;
          final dt = reportes[i].creadoEn.difference(reportes[j].creadoEn).abs();
          if (dt <= ventana && distanciaMetros(u.lat, u.lng, v.lat, v.lng) <= radioM) unir(i, j);
        }
      }
    }
  }

  final grupos = <int, List<Reporte>>{};
  for (var i = 0; i < n; i++) {
    grupos.putIfAbsent(raiz(i), () => []).add(reportes[i]);
  }
  return grupos.values.map(GrupoReportes.new).toList();
}
