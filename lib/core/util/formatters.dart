import 'package:intl/intl.dart';

final _hora = DateFormat('h:mm a', 'es_CO');
final _diaHora = DateFormat("d 'de' MMM, h:mm a", 'es_CO');

String horaCorta(DateTime d) => _hora.format(d.toLocal());
String diaYHora(DateTime d) => _diaHora.format(d.toLocal());

/// "hace 3 min", "hace 2 h", o el dia y la hora si pasaron mas de un dia.
String hace(DateTime d, {DateTime? ahora}) {
  final dif = (ahora ?? DateTime.now()).difference(d);
  if (dif.inSeconds < 60) return 'hace un momento';
  if (dif.inMinutes < 60) return 'hace ${dif.inMinutes} min';
  if (dif.inHours < 24) return 'hace ${dif.inHours} h';
  return diaYHora(d);
}

/// Primera letra en mayuscula, resto intacto.
String capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Telefono colombiano: 10 digitos, opcionalmente con 57 o +57 al inicio.
String? validarTelefono(String? v) {
  final d = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (d.isEmpty) return 'Escriba su número de teléfono.';
  final local = d.length == 12 && d.startsWith('57') ? d.substring(2) : d;
  if (local.length != 10 || !local.startsWith('3') && !local.startsWith('60')) {
    return 'Escriba un número de 10 dígitos, por ejemplo 3001234567.';
  }
  return null;
}

String normalizarTelefono(String v) {
  final d = v.replaceAll(RegExp(r'[^0-9]'), '');
  return d.length == 12 && d.startsWith('57') ? d.substring(2) : d;
}

/// Corrige solo los signos de apertura omitidos en el protocolo
/// ("El paciente está sangrando mucho?") y la mayuscula inicial.
String textoPregunta(String t) {
  var s = t.trim();
  if (s.endsWith('?') && !s.contains('¿')) s = '¿$s';
  final i = s.startsWith('¿') ? 1 : 0;
  return s.isEmpty ? s : s.substring(0, i) + capitalizar(s.substring(i));
}
