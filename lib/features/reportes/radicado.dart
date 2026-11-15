import 'dart:math';

const _alfabeto = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // sin 0/O, 1/I/L

/// Numero de radicado generado en el telefono, para poder entregarlo aunque
/// no haya red. Formato `BC-AAMMDD-XXXXXXX` (ej. BC-261119-K7M2QXA).
/// 31^7 = 27.500 millones de combinaciones por dia. Por la paradoja del
/// cumpleanos, con 5.000 reportes en un dia (emergencia masiva) la
/// probabilidad de que dos coincidan es de ~0,05 %; con 5 caracteres seria
/// de ~35 %, por eso son 7.
String generarRadicado(DateTime ahora, [Random? rng]) {
  final r = rng ?? Random.secure();
  final d = ahora.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  final fecha = '${dos(d.year % 100)}${dos(d.month)}${dos(d.day)}';
  final sufijo = List.generate(7, (_) => _alfabeto[r.nextInt(_alfabeto.length)]).join();
  return 'BC-$fecha-$sufijo';
}

final _forma = RegExp(r'^BC-\d{6}-[A-HJKMNP-Z2-9]{7}$');
bool radicadoValido(String s) => _forma.hasMatch(s);
