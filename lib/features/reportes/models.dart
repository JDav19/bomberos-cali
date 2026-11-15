import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

enum EstadoReporte {
  recibido('Recibido'),
  enVerificacion('En verificación'),
  despachado('Despachado'),
  atendido('Atendido'),
  cerrado('Cerrado');

  const EstadoReporte(this.etiqueta);
  final String etiqueta;

  bool get activo => this != atendido && this != cerrado;

  static EstadoReporte desde(String? v) =>
      EstadoReporte.values.firstWhere((e) => e.name == v, orElse: () => EstadoReporte.recibido);
}

/// Menor `peso` = mas urgente. Es criterio de la app (ver DECISIONES.md).
enum Prioridad {
  critica('Crítica', 0),
  alta('Alta', 1),
  media('Media', 2),
  baja('Baja', 3);

  const Prioridad(this.etiqueta, this.peso);
  final String etiqueta;
  final int peso;

  static Prioridad desde(String? v) =>
      Prioridad.values.firstWhere((e) => e.name == v, orElse: () => Prioridad.media);

  /// Sube la urgencia `niveles` pasos (hacia critica).
  Prioridad subir(int niveles) =>
      Prioridad.values[(peso - niveles).clamp(0, Prioridad.values.length - 1)];
}

enum TipoMedia { foto, video }

enum EstadoLlamada { ninguna, llamando, aceptada, rechazada, finalizada }

DateTime? _fecha(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

dynamic _salida(DateTime? d, bool firestore) =>
    d == null ? null : (firestore ? Timestamp.fromDate(d) : d.toUtc().toIso8601String());

class Ubicacion {
  const Ubicacion({required this.lat, required this.lng, this.precisionM, this.automatica = true});

  final double lat;
  final double lng;
  final double? precisionM;

  /// `false` cuando la persona no pudo compartir el GPS.
  final bool automatica;

  Map<String, dynamic> toMap() =>
      {'lat': lat, 'lng': lng, 'precisionM': precisionM, 'automatica': automatica};

  factory Ubicacion.fromMap(Map<String, dynamic> m) => Ubicacion(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        precisionM: (m['precisionM'] as num?)?.toDouble(),
        automatica: m['automatica'] as bool? ?? true,
      );
}

class MediaItem {
  const MediaItem({required this.url, required this.tipo, this.publicId, this.bytes});

  final String url;
  final TipoMedia tipo;
  final String? publicId;
  final int? bytes;

  /// Miniatura: Cloudinary entrega un fotograma del video si se pide como .jpg.
  String get miniatura {
    if (tipo == TipoMedia.foto) {
      return url.replaceFirst('/upload/', '/upload/c_limit,w_600,q_auto/');
    }
    final base = url.replaceFirst('/upload/', '/upload/c_limit,w_600,so_0/');
    final i = base.lastIndexOf('.');
    return i > 0 ? '${base.substring(0, i)}.jpg' : base;
  }

  Map<String, dynamic> toMap() =>
      {'url': url, 'tipo': tipo.name, 'publicId': publicId, 'bytes': bytes};

  factory MediaItem.fromMap(Map<String, dynamic> m) => MediaItem(
        url: m['url'] as String,
        tipo: TipoMedia.values.firstWhere((t) => t.name == m['tipo'], orElse: () => TipoMedia.foto),
        publicId: m['publicId'] as String?,
        bytes: (m['bytes'] as num?)?.toInt(),
      );
}

class Videollamada {
  const Videollamada({
    this.estado = EstadoLlamada.ninguna,
    this.canal,
    this.operadorNombre,
    this.creadaEn,
  });

  final EstadoLlamada estado;
  final String? canal;
  final String? operadorNombre;
  final DateTime? creadaEn;

  bool get activa => estado == EstadoLlamada.llamando || estado == EstadoLlamada.aceptada;

  Map<String, dynamic> toMap({bool firestore = true}) => {
        'estado': estado.name,
        'canal': canal,
        'operadorNombre': operadorNombre,
        'creadaEn': _salida(creadaEn, firestore),
      };

  factory Videollamada.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const Videollamada();
    return Videollamada(
      estado: EstadoLlamada.values
          .firstWhere((e) => e.name == m['estado'], orElse: () => EstadoLlamada.ninguna),
      canal: m['canal'] as String?,
      operadorNombre: m['operadorNombre'] as String?,
      creadaEn: _fecha(m['creadaEn']),
    );
  }
}

class CambioEstado {
  const CambioEstado({required this.estado, required this.en, this.por});

  final EstadoReporte estado;
  final DateTime en;
  final String? por;

  Map<String, dynamic> toMap({bool firestore = true}) =>
      {'estado': estado.name, 'en': _salida(en, firestore), 'por': por};

  factory CambioEstado.fromMap(Map<String, dynamic> m) => CambioEstado(
        estado: EstadoReporte.desde(m['estado'] as String?),
        en: _fecha(m['en']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        por: m['por'] as String?,
      );
}

class Reporte {
  Reporte({
    required this.radicado,
    required this.uid,
    required this.nombre,
    required this.telefono,
    required this.categoria,
    required this.categoriaNombre,
    this.tarjetaId,
    this.tarjetaNombre,
    required this.ubicacion,
    this.referencia,
    this.descripcion,
    this.estado = EstadoReporte.recibido,
    this.prioridad = Prioridad.media,
    required this.creadoEn,
    this.media = const [],
    this.mediaPendiente = 0,
    this.respuestas = const {},
    this.cuestionarioCompleto = false,
    this.videollamada = const Videollamada(),
    this.historial = const [],
    this.dispositivoId,
    this.registrado = false,
    this.operadorUid,
    this.nota,
  });

  /// Numero de radicado. Tambien es el id del documento.
  final String radicado;
  final String uid;
  final String nombre;
  final String telefono;

  /// Codigo del protocolo: 100, 200, 300, 400, 500, 800, 900.
  final String categoria;
  final String categoriaNombre;
  final String? tarjetaId;
  final String? tarjetaNombre;
  final Ubicacion? ubicacion;
  final String? referencia;

  /// Texto libre corto. Es lo unico que se pide en categorias sin tarjeta guia.
  final String? descripcion;
  final EstadoReporte estado;
  final Prioridad prioridad;
  final DateTime creadoEn;
  final List<MediaItem> media;

  /// Archivos que el ciudadano todavia esta subiendo.
  final int mediaPendiente;
  final Map<String, String> respuestas;
  final bool cuestionarioCompleto;
  final Videollamada videollamada;
  final List<CambioEstado> historial;
  final String? dispositivoId;
  final bool registrado;
  final String? operadorUid;
  final String? nota;

  Reporte copyWith({
    EstadoReporte? estado,
    Prioridad? prioridad,
    List<MediaItem>? media,
    int? mediaPendiente,
    Map<String, String>? respuestas,
    bool? cuestionarioCompleto,
    Videollamada? videollamada,
    List<CambioEstado>? historial,
    String? operadorUid,
    String? nota,
  }) =>
      Reporte(
        radicado: radicado,
        uid: uid,
        nombre: nombre,
        telefono: telefono,
        categoria: categoria,
        categoriaNombre: categoriaNombre,
        tarjetaId: tarjetaId,
        tarjetaNombre: tarjetaNombre,
        ubicacion: ubicacion,
        referencia: referencia,
        descripcion: descripcion,
        estado: estado ?? this.estado,
        prioridad: prioridad ?? this.prioridad,
        creadoEn: creadoEn,
        media: media ?? this.media,
        mediaPendiente: mediaPendiente ?? this.mediaPendiente,
        respuestas: respuestas ?? this.respuestas,
        cuestionarioCompleto: cuestionarioCompleto ?? this.cuestionarioCompleto,
        videollamada: videollamada ?? this.videollamada,
        historial: historial ?? this.historial,
        dispositivoId: dispositivoId,
        registrado: registrado,
        operadorUid: operadorUid ?? this.operadorUid,
        nota: nota ?? this.nota,
      );

  /// `firestore: true` usa Timestamp; `false` usa texto ISO (cola offline local).
  Map<String, dynamic> toMap({bool firestore = true}) => {
        'radicado': radicado,
        'uid': uid,
        'nombre': nombre,
        'telefono': telefono,
        'categoria': categoria,
        'categoriaNombre': categoriaNombre,
        'tarjetaId': tarjetaId,
        'tarjetaNombre': tarjetaNombre,
        'ubicacion': ubicacion?.toMap(),
        'referencia': referencia,
        'descripcion': descripcion,
        'estado': estado.name,
        'prioridad': prioridad.name,
        'prioridadPeso': prioridad.peso,
        'creadoEn': _salida(creadoEn, firestore),
        'media': media.map((m) => m.toMap()).toList(),
        'mediaPendiente': mediaPendiente,
        'respuestas': respuestas,
        'cuestionarioCompleto': cuestionarioCompleto,
        'videollamada': videollamada.toMap(firestore: firestore),
        'historial': historial.map((h) => h.toMap(firestore: firestore)).toList(),
        'dispositivoId': dispositivoId,
        'registrado': registrado,
        'operadorUid': operadorUid,
        'nota': nota,
      };

  factory Reporte.fromMap(Map<String, dynamic> m) {
    final ub = m['ubicacion'];
    return Reporte(
      radicado: m['radicado'] as String,
      uid: m['uid'] as String,
      nombre: m['nombre'] as String? ?? '',
      telefono: m['telefono'] as String? ?? '',
      categoria: m['categoria'] as String? ?? '900',
      categoriaNombre: m['categoriaNombre'] as String? ?? '',
      tarjetaId: m['tarjetaId'] as String?,
      tarjetaNombre: m['tarjetaNombre'] as String?,
      ubicacion: ub is Map ? Ubicacion.fromMap(Map<String, dynamic>.from(ub)) : null,
      referencia: m['referencia'] as String?,
      descripcion: m['descripcion'] as String?,
      estado: EstadoReporte.desde(m['estado'] as String?),
      prioridad: Prioridad.desde(m['prioridad'] as String?),
      creadoEn: _fecha(m['creadoEn']) ?? DateTime.now(),
      media: [
        for (final x in (m['media'] as List? ?? const [])) MediaItem.fromMap(Map<String, dynamic>.from(x as Map))
      ],
      mediaPendiente: (m['mediaPendiente'] as num?)?.toInt() ?? 0,
      respuestas: {
        for (final e in ((m['respuestas'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'
      },
      cuestionarioCompleto: m['cuestionarioCompleto'] as bool? ?? false,
      videollamada: Videollamada.fromMap(
          m['videollamada'] is Map ? Map<String, dynamic>.from(m['videollamada'] as Map) : null),
      historial: [
        for (final x in (m['historial'] as List? ?? const []))
          CambioEstado.fromMap(Map<String, dynamic>.from(x as Map))
      ],
      dispositivoId: m['dispositivoId'] as String?,
      registrado: m['registrado'] as bool? ?? false,
      operadorUid: m['operadorUid'] as String?,
      nota: m['nota'] as String?,
    );
  }
}
