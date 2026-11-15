import '../protocolo/protocolo.dart';
import 'models.dart';

/// Prioridad automatica. CRITERIO DE LA APP, no del protocolo: el protocolo no
/// trae niveles de prioridad en su texto. Se parte de la tarjeta/categoria y
/// las respuestas clave solo pueden subirla. El operador siempre puede
/// cambiarla. Ver docs/DECISIONES.md.
const _criticas = {
  'ataque_cardiaco',
  'obstruccion_via_aerea',
  'ahogamiento',
  'inconsciente',
  'rescate_estructura_colapsada',
  'vehiculo_en_agua',
  'caida_en_rio',
  'incendio_edificio_alto',
  'incendio_concentracion_masiva',
};

const _medias = {
  'dolor_cabeza',
  'dolor_espalda',
  'enfermo',
  'ojos',
  'mordedura_animal',
  'enfermedad_infecciosa',
  'psiquiatrico',
  'persona_encerrada',
  'extraviado_zona_rural',
  'incendio_basuras_edificacion',
  'incendio_basuras_exterior',
  'incendio_lote_urbano',
  'incendio_arbustos_pastos',
  'olor_desconocido',
  'derrame_liquido',
  'corto_circuito',
  'estructura_colapsada_sin_atrapados',
};

Prioridad prioridadBase(String categoria, String? tarjetaId) {
  if (tarjetaId != null) {
    if (_criticas.contains(tarjetaId)) return Prioridad.critica;
    if (_medias.contains(tarjetaId)) return Prioridad.media;
  }
  return switch (categoria) {
    '100' || '200' || '300' => Prioridad.alta,
    '400' || '800' || '900' => Prioridad.media,
    _ => Prioridad.baja,
  };
}

Prioridad calcularPrioridad({
  required String categoria,
  String? tarjetaId,
  Map<String, String> respuestas = const {},
  List<PreguntaClave> claves = const [],
}) {
  var p = prioridadBase(categoria, tarjetaId);
  var subir = 0;
  for (final q in claves) {
    final r = respuestas[q.clave];
    if (r == null || r.isEmpty) continue;
    final e = q.efecto;
    if (e.critica.contains(r)) return Prioridad.critica;
    if (q.tipo == TipoPregunta.numero) {
      final n = int.tryParse(r);
      if (n != null && e.umbral != null && n >= e.umbral!) subir += e.sube['si'] ?? 0;
    } else {
      subir += e.sube[r] ?? 0;
    }
  }
  // Sube a lo sumo dos niveles, sin importar cuantas respuestas graves haya.
  if (subir > 0) p = p.subir(subir > 1 ? 2 : 1);
  return p;
}
