import 'dart:convert';
import 'dart:io';

import 'package:bomberos_cali/features/protocolo/protocolo.dart';
import 'package:bomberos_cali/features/reportes/cola_offline.dart';
import 'package:bomberos_cali/features/reportes/models.dart';

Reporte reporteDe({
  String radicado = 'BC-261119-AAAAA',
  double? lat = 3.4516,
  double? lng = -76.5320,
  DateTime? en,
  String categoria = '300',
  String? tarjetaId = 'trauma',
  Prioridad prioridad = Prioridad.alta,
  EstadoReporte estado = EstadoReporte.recibido,
}) =>
    Reporte(
      radicado: radicado,
      uid: 'u1',
      nombre: 'Ana Gómez',
      telefono: '3001234567',
      categoria: categoria,
      categoriaNombre: 'Rescates y emergencias médicas',
      tarjetaId: tarjetaId,
      tarjetaNombre: 'Trauma',
      ubicacion: lat == null ? null : Ubicacion(lat: lat, lng: lng!, precisionM: 12),
      prioridad: prioridad,
      estado: estado,
      creadoEn: en ?? DateTime.utc(2026, 11, 19, 15, 0),
    );

/// Carga el protocolo real desde assets/protocolo sin Flutter.
Protocolo protocoloDeDisco() {
  Map<String, dynamic> leer(String n) =>
      json.decode(File('assets/protocolo/$n.json').readAsStringSync()) as Map<String, dynamic>;
  return Protocolo.desdeJson(
    categorias: [
      for (final n in const [
        '100_incendios',
        '200_explosion',
        '300_rescates_medicas',
        '400_condiciones_peligrosas',
        '500_servicio',
        '800_clima_desastres',
        '900_especial',
      ])
        leer(n)
    ],
    procedimientos: leer('procedimientos'),
    preguntasClave: leer('preguntas_clave'),
  );
}

class AlmacenFalso implements ColaStorage {
  String? contenido;
  @override
  Future<String?> leer() async => contenido;
  @override
  Future<void> escribir(String c) async => contenido = c;
}

class BackendFalso implements EnvioBackend {
  bool enLinea = true;
  bool fallaSubida = false;
  bool subidaPermanente = false;
  final List<String> creados = [];
  final List<String> mediaAgregada = [];
  final List<String> orden = [];
  int descartes = 0;
  int intentosSubida = 0;

  @override
  Future<void> crearReporte(Reporte r) async {
    if (!enLinea) throw ErrorReintentable('sin red');
    creados.add(r.radicado);
    orden.add('doc');
  }

  @override
  Future<MediaItem> subirArchivo(ArchivoPendiente a) async {
    intentosSubida++;
    if (subidaPermanente) throw ErrorPermanente('archivo invalido');
    if (!enLinea || fallaSubida) throw ErrorReintentable('sin red');
    orden.add('archivo');
    return MediaItem(url: 'https://res.cloudinary.com/x/image/upload/${a.ruta}.jpg', tipo: a.tipo);
  }

  @override
  Future<void> agregarMedia(String radicado, MediaItem m) async {
    if (!enLinea) throw ErrorReintentable('sin red');
    mediaAgregada.add(m.url);
  }

  @override
  Future<void> descartarPendiente(String radicado) async {
    descartes++;
  }
}
