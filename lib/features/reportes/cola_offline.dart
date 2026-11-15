import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';

/// El envio falla por red o servidor: se reintenta mas tarde.
class ErrorReintentable implements Exception {
  ErrorReintentable(this.mensaje);
  final String mensaje;
  @override
  String toString() => 'ErrorReintentable: $mensaje';
}

/// El envio no se puede completar nunca (archivo borrado, formato invalido).
class ErrorPermanente implements Exception {
  ErrorPermanente(this.mensaje);
  final String mensaje;
  @override
  String toString() => 'ErrorPermanente: $mensaje';
}

abstract interface class ColaStorage {
  Future<String?> leer();
  Future<void> escribir(String contenido);
}

/// Lo que la cola necesita del mundo exterior. Se separa para poder probar la
/// logica de reintentos sin Firebase ni red.
abstract interface class EnvioBackend {
  /// Crea el documento del reporte (idempotente por radicado).
  Future<void> crearReporte(Reporte r);

  /// Comprime y sube un archivo. Devuelve lo que quedo en la nube.
  Future<MediaItem> subirArchivo(ArchivoPendiente a);

  /// Agrega el archivo subido al reporte y descuenta uno de `mediaPendiente`.
  Future<void> agregarMedia(String radicado, MediaItem m);

  /// Descuenta un pendiente cuando un archivo se descarta para siempre.
  Future<void> descartarPendiente(String radicado);
}

class ArchivoPendiente {
  ArchivoPendiente({required this.ruta, required this.tipo, this.intentos = 0});

  final String ruta;
  final TipoMedia tipo;
  int intentos;

  Map<String, dynamic> toMap() => {'ruta': ruta, 'tipo': tipo.name, 'intentos': intentos};

  factory ArchivoPendiente.fromMap(Map<String, dynamic> m) => ArchivoPendiente(
        ruta: m['ruta'] as String,
        tipo: TipoMedia.values.firstWhere((t) => t.name == m['tipo']),
        intentos: (m['intentos'] as num?)?.toInt() ?? 0,
      );
}

class ItemCola {
  ItemCola({
    required this.reporte,
    required this.archivos,
    this.documentoEnviado = false,
    this.intentos = 0,
    this.proximoIntento,
  });

  Reporte reporte;
  final List<ArchivoPendiente> archivos;
  bool documentoEnviado;
  int intentos;
  DateTime? proximoIntento;

  String get radicado => reporte.radicado;
  bool get completo => documentoEnviado && archivos.isEmpty;

  Map<String, dynamic> toMap() => {
        'reporte': reporte.toMap(firestore: false),
        'archivos': archivos.map((a) => a.toMap()).toList(),
        'documentoEnviado': documentoEnviado,
        'intentos': intentos,
        'proximoIntento': proximoIntento?.toUtc().toIso8601String(),
      };

  factory ItemCola.fromMap(Map<String, dynamic> m) => ItemCola(
        reporte: Reporte.fromMap(Map<String, dynamic>.from(m['reporte'] as Map)),
        archivos: [
          for (final a in (m['archivos'] as List)) ArchivoPendiente.fromMap(Map<String, dynamic>.from(a as Map))
        ],
        documentoEnviado: m['documentoEnviado'] as bool? ?? false,
        intentos: (m['intentos'] as num?)?.toInt() ?? 0,
        proximoIntento: DateTime.tryParse(m['proximoIntento'] as String? ?? ''),
      );
}

/// Espera antes del intento numero `intentos` (1, 2, 3...): 5 s, 10 s, 20 s...
/// con tope de 5 minutos. Retroceso exponencial para no saturar la red ni
/// el servidor cuando muchos telefonos reintentan a la vez.
Duration esperaReintento(int intentos) {
  final seg = 5 * pow(2, max(0, intentos - 1)).toInt();
  return Duration(seconds: min(seg, 300));
}

/// Cola persistente de reportes por enviar. Primero sube el reporte (texto y
/// coordenadas) y despues cada archivo, para que el reporte llegue aunque la
/// subida de fotos o video falle.
class ColaOffline extends ChangeNotifier {
  ColaOffline({
    required this._storage,
    required this._backend,
    DateTime Function()? reloj,
    this.maxIntentosArchivo = 8,
  }) : _reloj = reloj ?? DateTime.now;

  final ColaStorage _storage;
  final EnvioBackend _backend;
  final DateTime Function() _reloj;
  final int maxIntentosArchivo;

  final List<ItemCola> _items = [];
  bool _procesando = false;
  Timer? _timer;

  List<ItemCola> get items => List.unmodifiable(_items);
  bool get procesando => _procesando;
  int get pendientes => _items.length;

  ItemCola? porRadicado(String radicado) {
    for (final i in _items) {
      if (i.radicado == radicado) return i;
    }
    return null;
  }

  Future<void> cargar() async {
    final raw = await _storage.leer();
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        for (final m in (json.decode(raw) as List)) {
          _items.add(ItemCola.fromMap(Map<String, dynamic>.from(m as Map)));
        }
      } catch (_) {
        // Archivo danado: se empieza vacio antes que bloquear la app.
      }
    }
    notifyListeners();
  }

  Future<void> _guardar() => _storage.escribir(json.encode(_items.map((i) => i.toMap()).toList()));

  /// Cambia el reporte de un item aun no enviado (por ejemplo al agregar
  /// las respuestas del cuestionario antes de que haya red).
  Future<bool> reemplazarSiPendiente(Reporte nuevo) async {
    final i = porRadicado(nuevo.radicado);
    if (i == null || i.documentoEnviado) return false;
    i.reporte = nuevo;
    await _guardar();
    notifyListeners();
    return true;
  }

  /// Guarda el reporte localmente y lo deja listo para enviar.
  Future<void> encolar(Reporte r, List<ArchivoPendiente> archivos) async {
    _items.add(ItemCola(reporte: r, archivos: archivos));
    await _guardar();
    notifyListeners();
  }

  /// Procesa todo lo pendiente cuyo turno ya llego. Seguro de llamar muchas
  /// veces (al abrir la app, al volver la red, por temporizador).
  Future<void> procesar({bool ignorarEspera = false}) async {
    if (_procesando) return;
    _procesando = true;
    notifyListeners();
    try {
      for (final item in List.of(_items)) {
        final turno = item.proximoIntento;
        if (!ignorarEspera && turno != null && turno.isAfter(_reloj())) continue;
        await _procesarItem(item);
      }
    } finally {
      _procesando = false;
      _programar();
      notifyListeners();
    }
  }

  Future<void> _procesarItem(ItemCola item) async {
    var huboFallo = false;

    if (!item.documentoEnviado) {
      try {
        await _backend.crearReporte(item.reporte);
        item.documentoEnviado = true;
      } on ErrorReintentable {
        huboFallo = true;
      }
      await _guardar();
    }

    if (item.documentoEnviado) {
      for (final a in List.of(item.archivos)) {
        try {
          final subido = await _backend.subirArchivo(a);
          await _backend.agregarMedia(item.radicado, subido);
          item.archivos.remove(a);
        } on ErrorPermanente {
          await _descartar(item, a);
        } on ErrorReintentable {
          a.intentos++;
          if (a.intentos >= maxIntentosArchivo) {
            await _descartar(item, a);
          } else {
            huboFallo = true;
          }
        }
        await _guardar();
      }
    }

    if (item.completo) {
      _items.remove(item);
      item.proximoIntento = null;
    } else if (huboFallo) {
      item.intentos++;
      item.proximoIntento = _reloj().add(esperaReintento(item.intentos));
    } else {
      item.intentos = 0;
      item.proximoIntento = null;
    }
    await _guardar();
  }

  Future<void> _descartar(ItemCola item, ArchivoPendiente a) async {
    item.archivos.remove(a);
    try {
      await _backend.descartarPendiente(item.radicado);
    } on Exception {
      // Si tampoco se puede descontar, el operador vera "archivos en camino"
      // hasta que el ciudadano abra el reporte; no es critico.
    }
  }

  /// Agenda el siguiente reintento segun el turno mas cercano.
  void _programar() {
    _timer?.cancel();
    DateTime? proximo;
    for (final i in _items) {
      final t = i.proximoIntento ?? _reloj();
      if (proximo == null || t.isBefore(proximo)) proximo = t;
    }
    if (proximo == null) return;
    var espera = proximo.difference(_reloj());
    if (espera < const Duration(seconds: 2)) espera = const Duration(seconds: 2);
    _timer = Timer(espera, () => procesar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
