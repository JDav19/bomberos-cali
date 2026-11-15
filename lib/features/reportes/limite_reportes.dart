/// Limite de reportes por dispositivo en una ventana de tiempo.
///
/// 3 reportes cada 10 minutos: una persona real rara vez reporta mas de tres
/// emergencias distintas en ese lapso, y un script o una pulsacion repetida
/// si. Cuando se alcanza el limite la app no bloquea sin salida: muestra el
/// boton del 119 y el tiempo que falta. El limite es del lado del cliente
/// (sin Cloud Functions no hay forma de forzarlo en el servidor sin plan de
/// pago); ver DECISIONES.md.
class LimiteReportes {
  const LimiteReportes({this.maximo = 3, this.ventana = const Duration(minutes: 10)});

  final int maximo;
  final Duration ventana;

  List<DateTime> _vigentes(List<DateTime> envios, DateTime ahora) =>
      envios.where((e) => ahora.difference(e) < ventana && !e.isAfter(ahora)).toList()..sort();

  bool permite(List<DateTime> envios, DateTime ahora) => _vigentes(envios, ahora).length < maximo;

  /// Cuanto falta para poder enviar otro. `null` si ya se puede.
  Duration? esperar(List<DateTime> envios, DateTime ahora) {
    final v = _vigentes(envios, ahora);
    if (v.length < maximo) return null;
    return ventana - ahora.difference(v[v.length - maximo]);
  }

  /// Conserva solo los envios que aun cuentan.
  List<DateTime> podar(List<DateTime> envios, DateTime ahora) => _vigentes(envios, ahora);
}
