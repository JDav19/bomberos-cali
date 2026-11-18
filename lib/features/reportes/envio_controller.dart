import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/util/servicios_dispositivo.dart';
import '../auth/auth_service.dart';
import '../protocolo/protocolo.dart';
import 'cola_offline.dart';
import 'limite_reportes.dart';
import 'media_service.dart';
import 'models.dart';
import 'prioridad.dart';
import 'radicado.dart';
import 'reportes_repository.dart';

class ArchivoElegido {
  const ArchivoElegido(this.ruta, this.tipo);
  final String ruta;
  final TipoMedia tipo;
}

class BorradorReporte {
  BorradorReporte({
    required this.categoria,
    this.tarjeta,
    this.descripcion,
    this.referencia,
    required this.nombre,
    required this.telefono,
    this.ubicacion,
    this.archivos = const [],
  });

  final Categoria categoria;
  final Tarjeta? tarjeta;
  final String? descripcion;
  final String? referencia;
  final String nombre;
  final String telefono;
  final Ubicacion? ubicacion;
  final List<ArchivoElegido> archivos;
}

/// Se alcanzo el limite de reportes por dispositivo.
class LimiteExcedido implements Exception {
  LimiteExcedido(this.espera);
  final Duration espera;
}

/// Orquesta el envio: arma el reporte, lo guarda en la cola local y dispara el
/// envio. El reporte (texto y coordenadas) sale primero y los archivos despues.
class EnvioController extends ChangeNotifier {
  EnvioController({
    required this.auth,
    required this.cola,
    required this.repo,
    required this.media,
    required this.dispositivo,
    this.limite = const LimiteReportes(),
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  final AuthService auth;
  final ColaOffline cola;
  final ReportesRepository repo;
  final MediaService media;
  final DispositivoService dispositivo;
  final LimiteReportes limite;
  final DateTime Function() _reloj;

  Duration? esperaPorLimite() => limite.esperar(dispositivo.envios, _reloj());

  Future<Reporte> enviar(BorradorReporte b) async {
    final ahora = _reloj();
    final previos = dispositivo.envios;
    final espera = limite.esperar(previos, ahora);
    if (espera != null) throw LimiteExcedido(espera);

    final uid = auth.uid;
    if (uid == null) throw StateError('Sin sesion');

    final archivos = <ArchivoPendiente>[];
    for (final a in b.archivos) {
      archivos.add(ArchivoPendiente(ruta: await media.guardarParaCola(a.ruta), tipo: a.tipo));
    }

    final r = Reporte(
      radicado: generarRadicado(ahora),
      uid: uid,
      nombre: b.nombre.trim(),
      telefono: normalizarTel(b.telefono),
      categoria: b.categoria.codigo,
      categoriaNombre: b.categoria.nombre,
      tarjetaId: b.tarjeta?.id,
      tarjetaNombre: b.tarjeta?.nombre,
      ubicacion: b.ubicacion,
      referencia: _vacioANulo(b.referencia),
      descripcion: _vacioANulo(b.descripcion),
      prioridad: prioridadBase(b.categoria.codigo, b.tarjeta?.id),
      creadoEn: ahora,
      mediaPendiente: archivos.length,
      dispositivoId: dispositivo.id,
      registrado: auth.registrado,
      historial: [CambioEstado(estado: EstadoReporte.recibido, en: ahora, por: 'app')],
    );

    await cola.encolar(r, archivos);
    await dispositivo.guardarEnvios([...limite.podar(previos, ahora), ahora]);
    if (r.nombre.isNotEmpty && r.telefono.isNotEmpty) await dispositivo.recordarContacto(r.nombre, r.telefono);
    unawaited(cola.procesar(ignorarEspera: true));
    notifyListeners();
    return r;
  }

  /// Agrega fotos o videos a un reporte ya enviado. Se guardan en la cola del
  /// telefono y se suben solos, igual que los del primer envio.
  Future<void> agregarArchivos(Reporte r, List<ArchivoElegido> elegidos) async {
    if (elegidos.isEmpty) return;
    final nuevos = <ArchivoPendiente>[];
    for (final a in elegidos) {
      nuevos.add(ArchivoPendiente(ruta: await media.guardarParaCola(a.ruta), tipo: a.tipo));
    }
    final remoto = await cola.agregarArchivos(r, nuevos);
    if (remoto) {
      try {
        await repo.sumarPendientes(r.radicado, nuevos.length).timeout(const Duration(seconds: 6));
      } on TimeoutException {
        // Queda pendiente en el SDK y se envia solo al volver la red.
      }
    }
    unawaited(cola.procesar(ignorarEspera: true));
    notifyListeners();
  }

  /// Completa un reporte ya enviado (normalmente uno rapido): tipo, descripcion,
  /// referencia y datos de contacto. La prioridad solo puede subir; si el
  /// operador la bajo o la subio a mano, no se le pisa hacia abajo.
  Future<Reporte> actualizarDetalles(
    Reporte r, {
    required String nombre,
    required String telefono,
    required Categoria categoria,
    Tarjeta? tarjeta,
    String? descripcion,
    String? referencia,
  }) async {
    final base = prioridadBase(categoria.codigo, tarjeta?.id);
    final nuevo = r.copyWith(
      nombre: nombre.trim(),
      telefono: normalizarTel(telefono),
      categoria: categoria.codigo,
      categoriaNombre: categoria.nombre,
      tarjetaId: tarjeta?.id,
      tarjetaNombre: tarjeta?.nombre,
      sinTarjeta: tarjeta == null,
      descripcion: _vacioANulo(descripcion),
      referencia: _vacioANulo(referencia),
      prioridad: base.peso < r.prioridad.peso ? base : r.prioridad,
    );
    if (nuevo.nombre.isNotEmpty && nuevo.telefono.isNotEmpty) {
      await dispositivo.recordarContacto(nuevo.nombre, nuevo.telefono);
    }
    if (await cola.reemplazarSiPendiente(nuevo)) return nuevo;
    try {
      await repo.actualizarDetalles(nuevo).timeout(const Duration(seconds: 6));
    } on TimeoutException {
      // Queda pendiente en el SDK y se envia solo al volver la red.
    }
    return nuevo;
  }

  /// Agrega las respuestas del cuestionario al mismo reporte y recalcula la
  /// prioridad. Si el reporte aun esta en la cola local, lo actualiza ahi.
  Future<Prioridad> complementar(Reporte r, Map<String, String> respuestas, List<PreguntaClave> claves) async {
    final p = calcularPrioridad(
      categoria: r.categoria,
      tarjetaId: r.tarjetaId,
      respuestas: respuestas,
      claves: claves,
    );
    final nuevo = r.copyWith(respuestas: respuestas, prioridad: p, cuestionarioCompleto: true);
    if (await cola.reemplazarSiPendiente(nuevo)) return p;
    // Firestore guarda la escritura localmente si no hay red y la envia sola
    // al volver; por eso no se espera mas de unos segundos.
    try {
      await repo.guardarRespuestas(r.radicado, respuestas, p).timeout(const Duration(seconds: 6));
    } on TimeoutException {
      // Queda pendiente en el SDK.
    }
    return p;
  }

  static String normalizarTel(String v) {
    final d = v.replaceAll(RegExp(r'[^0-9]'), '');
    return d.length == 12 && d.startsWith('57') ? d.substring(2) : d;
  }

  static String? _vacioANulo(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
}
