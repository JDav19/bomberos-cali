import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'cola_offline.dart';
import 'models.dart';

/// Acceso a los reportes en Cloud Firestore. Un documento por reporte, con el
/// radicado como id. Sin Firebase Storage ni Cloud Functions (ver DECISIONES.md).
class ReportesRepository implements EnvioBackend {
  ReportesRepository(this._db, {required this.subir});

  final FirebaseFirestore _db;

  /// Comprime y sube a Cloudinary. Se inyecta para no acoplar este archivo.
  final Future<MediaItem> Function(ArchivoPendiente) subir;

  static const _timeoutRed = Duration(seconds: 15);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('reportes');

  Reporte _desde(DocumentSnapshot<Map<String, dynamic>> d) => Reporte.fromMap(d.data()!);

  // ---- Lectura ----

  /// Reportes del ciudadano. Se ordena en el cliente para no exigir un
  /// indice compuesto en Firestore.
  Stream<List<Reporte>> misReportes(String uid) => _col.where('uid', isEqualTo: uid).snapshots().map((s) {
        final l = s.docs.map(_desde).toList()..sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
        return l;
      });

  /// Todos los reportes (solo operadores). Los 400 mas recientes.
  Stream<List<Reporte>> todos({int limite = 400}) =>
      _col.orderBy('creadoEn', descending: true).limit(limite).snapshots().map((s) => s.docs.map(_desde).toList());

  Stream<Reporte?> reporte(String radicado) =>
      _col.doc(radicado).snapshots().map((d) => d.exists ? _desde(d) : null);

  // ---- Escritura del ciudadano (EnvioBackend) ----

  @override
  Future<void> crearReporte(Reporte r) async {
    final datos = r.toMap()..['recibidoEn'] = FieldValue.serverTimestamp();
    try {
      // Sin merge: si el documento ya existe (reintento tras un envio que si
      // llego), las reglas lo rechazan con permission-denied y lo damos por
      // enviado en vez de pisar el estado que haya puesto el operador.
      await _col.doc(r.radicado).set(datos).timeout(_timeoutRed);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        final ya = await _col.doc(r.radicado).get().timeout(_timeoutRed, onTimeout: () => throw ErrorReintentable('timeout'));
        if (ya.exists) return;
      }
      throw ErrorReintentable(e.code);
    } on TimeoutException {
      throw ErrorReintentable('timeout');
    }
  }

  @override
  Future<MediaItem> subirArchivo(ArchivoPendiente a) => subir(a);

  @override
  Future<void> agregarMedia(String radicado, MediaItem m) async {
    try {
      await _col.doc(radicado).update({
        'media': FieldValue.arrayUnion([m.toMap()]),
        'mediaPendiente': FieldValue.increment(-1),
      }).timeout(_timeoutRed);
    } on FirebaseException catch (e) {
      throw ErrorReintentable(e.code);
    } on TimeoutException {
      throw ErrorReintentable('timeout');
    }
  }

  @override
  Future<void> descartarPendiente(String radicado) async {
    try {
      await _col.doc(radicado).update({'mediaPendiente': FieldValue.increment(-1)}).timeout(_timeoutRed);
    } on FirebaseException catch (e) {
      throw ErrorReintentable(e.code);
    }
  }

  /// Complemento: respuestas del cuestionario. Se agregan al mismo reporte.
  Future<void> guardarRespuestas(
    String radicado,
    Map<String, String> respuestas,
    Prioridad prioridad,
  ) =>
      _col.doc(radicado).update({
        'respuestas': respuestas,
        'cuestionarioCompleto': true,
        'prioridad': prioridad.name,
        'prioridadPeso': prioridad.peso,
      });

  Future<void> responderVideollamada(String radicado, EstadoLlamada estado) =>
      _col.doc(radicado).update({'videollamada.estado': estado.name});

  // ---- Escritura del operador ----

  Future<void> cambiarEstado(String radicado, EstadoReporte estado, String operadorUid) => _col.doc(radicado).update({
        'estado': estado.name,
        'operadorUid': operadorUid,
        'historial': FieldValue.arrayUnion([CambioEstado(estado: estado, en: DateTime.now(), por: operadorUid).toMap()]),
      });

  Future<void> cambiarPrioridad(String radicado, Prioridad p) =>
      _col.doc(radicado).update({'prioridad': p.name, 'prioridadPeso': p.peso});

  Future<void> guardarNota(String radicado, String nota) => _col.doc(radicado).update({'nota': nota});

  Future<void> iniciarVideollamada(String radicado, String operadorNombre) => _col.doc(radicado).update({
        'videollamada': Videollamada(
          estado: EstadoLlamada.llamando,
          canal: radicado,
          operadorNombre: operadorNombre,
          creadaEn: DateTime.now(),
        ).toMap(),
      });

  Future<void> terminarVideollamada(String radicado) =>
      _col.doc(radicado).update({'videollamada.estado': EstadoLlamada.finalizada.name});

  /// Crea un reporte a nombre de otro ciudadano (seed y registro de llamadas al 119).
  Future<void> crearComoOperador(Reporte r) => _col.doc(r.radicado).set(r.toMap());
}
