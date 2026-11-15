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
    await dispositivo.recordarContacto(r.nombre, r.telefono);
    unawaited(cola.procesar(ignorarEspera: true));
    notifyListeners();
    return r;
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
