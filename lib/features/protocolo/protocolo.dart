import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;

/// Efecto de una respuesta sobre la prioridad. Es criterio de la app,
/// no del protocolo (ver docs/DECISIONES.md).
class EfectoPrioridad {
  const EfectoPrioridad({this.critica = const [], this.sube = const {}, this.umbral});

  /// Respuestas que llevan la prioridad directamente a critica.
  final List<String> critica;

  /// Respuesta -> niveles que sube.
  final Map<String, int> sube;

  /// Para preguntas numericas: desde este valor aplica `sube['si']`.
  final int? umbral;

  factory EfectoPrioridad.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const EfectoPrioridad();
    return EfectoPrioridad(
      critica: [for (final x in (m['critica'] as List? ?? const [])) '$x'],
      sube: {for (final e in ((m['sube'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt()},
      umbral: (m['umbral'] as num?)?.toInt(),
    );
  }
}

enum TipoPregunta { siNo, numero, texto }

class PreguntaClave {
  const PreguntaClave({
    required this.clave,
    required this.tipo,
    required this.texto,
    required this.fuente,
    required this.efecto,
  });

  final String clave;
  final TipoPregunta tipo;

  /// Oracion literal del protocolo.
  final String texto;
  final int fuente;
  final EfectoPrioridad efecto;

  factory PreguntaClave.fromMap(Map<String, dynamic> m) => PreguntaClave(
        clave: m['clave'] as String,
        tipo: switch (m['tipo']) {
          'numero' => TipoPregunta.numero,
          'texto' => TipoPregunta.texto,
          _ => TipoPregunta.siNo,
        },
        texto: m['texto'] as String,
        fuente: (m['fuente'] as num).toInt(),
        efecto: EfectoPrioridad.fromMap(m['efecto'] as Map<String, dynamic>?),
      );
}

class DestinoRef {
  const DestinoRef({required this.tipo, this.id, this.grupo, this.nodo, this.numero});

  /// `tarjeta`, `procedimiento` o `diapositiva` (sin contenido en la app).
  final String tipo;
  final String? id;
  final String? grupo;
  final int? nodo;
  final int? numero;

  bool get esTarjeta => tipo == 'tarjeta';
  bool get esProcedimiento => tipo == 'procedimiento';

  static DestinoRef? fromMap(Map<String, dynamic>? m) => m == null
      ? null
      : DestinoRef(
          tipo: m['tipo'] as String,
          id: m['id'] as String?,
          grupo: m['grupo'] as String?,
          nodo: (m['nodo'] as num?)?.toInt(),
          numero: (m['numero'] as num?)?.toInt(),
        );
}

class Referencia {
  const Referencia({required this.texto, this.diapositiva, this.destino});

  final String texto;
  final int? diapositiva;
  final DestinoRef? destino;

  factory Referencia.fromMap(Map<String, dynamic> m) => Referencia(
        texto: m['texto'] as String,
        diapositiva: (m['diapositiva'] as num?)?.toInt(),
        destino: DestinoRef.fromMap(m['destino'] as Map<String, dynamic>?),
      );
}

class DespachoItem {
  const DespachoItem({this.codigo, required this.descripcion});

  final String? codigo;
  final String descripcion;

  factory DespachoItem.fromMap(Map<String, dynamic> m) =>
      DespachoItem(codigo: m['codigo'] as String?, descripcion: m['descripcion'] as String);
}

class SeccionPreArribo {
  const SeccionPreArribo({required this.diapositiva, required this.lineas, required this.referencias});

  final int diapositiva;
  final List<String> lineas;
  final List<Referencia> referencias;

  factory SeccionPreArribo.fromMap(Map<String, dynamic> m) => SeccionPreArribo(
        diapositiva: (m['diapositiva'] as num).toInt(),
        lineas: [for (final l in (m['lineas'] as List)) '$l'],
        referencias: [
          for (final r in (m['referencias'] as List? ?? const [])) Referencia.fromMap(r as Map<String, dynamic>)
        ],
      );
}

class Tarjeta {
  const Tarjeta({
    required this.id,
    required this.categoria,
    required this.nombre,
    this.numero,
    required this.preguntas,
    required this.despacho,
    required this.referencias,
    required this.preArribo,
    required this.notas,
  });

  final String id;
  final String categoria;
  final String nombre;
  final int? numero;
  final List<String> preguntas;
  final List<DespachoItem> despacho;
  final List<Referencia> referencias;
  final List<SeccionPreArribo> preArribo;
  final List<String> notas;

  factory Tarjeta.fromMap(Map<String, dynamic> m) => Tarjeta(
        id: m['id'] as String,
        categoria: m['categoria'] as String,
        nombre: m['nombre'] as String,
        numero: (m['numero_tarjeta'] as num?)?.toInt(),
        preguntas: [for (final p in (m['preguntas'] as List)) (p as Map)['texto'] as String],
        despacho: [for (final d in (m['despacho'] as List)) DespachoItem.fromMap(d as Map<String, dynamic>)],
        referencias: [
          for (final r in (m['referencias'] as List)) Referencia.fromMap(r as Map<String, dynamic>)
        ],
        preArribo: [
          for (final s in (m['pre_arribo'] as List)) SeccionPreArribo.fromMap(s as Map<String, dynamic>)
        ],
        notas: [for (final n in (m['notas'] as List)) '$n'],
      );
}

class Categoria {
  const Categoria({required this.codigo, required this.nombre, required this.tarjetas, this.nota});

  final String codigo;
  final String nombre;
  final List<Tarjeta> tarjetas;
  final String? nota;

  bool get tieneTarjetas => tarjetas.isNotEmpty;
}

class OpcionNodo {
  const OpcionNodo({required this.texto, this.destino, this.volver = false, this.destinoInfo});

  final String texto;
  final int? destino;
  final bool volver;
  final DestinoRef? destinoInfo;
}

class NodoProcedimiento {
  const NodoProcedimiento({
    required this.diapositiva,
    required this.grupo,
    required this.lineas,
    required this.opciones,
  });

  final int diapositiva;
  final String grupo;
  final List<String> lineas;
  final List<OpcionNodo> opciones;
}

class GrupoProcedimiento {
  const GrupoProcedimiento({required this.id, required this.nombre, required this.entrada});

  final String id;
  final String nombre;
  final int entrada;
}

class Protocolo {
  Protocolo._({
    required this.categorias,
    required this.grupos,
    required this.nodos,
    required this.clavesPorTarjeta,
  }) : _tarjetas = {for (final c in categorias) for (final t in c.tarjetas) t.id: t};

  final List<Categoria> categorias;
  final Map<String, GrupoProcedimiento> grupos;
  final Map<int, NodoProcedimiento> nodos;
  final Map<String, List<PreguntaClave>> clavesPorTarjeta;
  final Map<String, Tarjeta> _tarjetas;

  static const _archivos = [
    '100_incendios',
    '200_explosion',
    '300_rescates_medicas',
    '400_condiciones_peligrosas',
    '500_servicio',
    '800_clima_desastres',
    '900_especial',
  ];

  Tarjeta? tarjeta(String? id) => id == null ? null : _tarjetas[id];
  Categoria? categoria(String codigo) {
    for (final c in categorias) {
      if (c.codigo == codigo) return c;
    }
    return null;
  }

  List<PreguntaClave> clavesDe(String? tarjetaId) => clavesPorTarjeta[tarjetaId] ?? const [];

  /// Carga desde los assets empaquetados.
  static Future<Protocolo> cargar(AssetBundle bundle) async {
    Future<Map<String, dynamic>> leer(String n) async =>
        json.decode(await bundle.loadString('assets/protocolo/$n.json')) as Map<String, dynamic>;
    final cats = [for (final a in _archivos) await leer(a)];
    return Protocolo.desdeJson(
        categorias: cats, procedimientos: await leer('procedimientos'), preguntasClave: await leer('preguntas_clave'));
  }

  factory Protocolo.desdeJson({
    required List<Map<String, dynamic>> categorias,
    required Map<String, dynamic> procedimientos,
    required Map<String, dynamic> preguntasClave,
  }) {
    final cats = [
      for (final c in categorias)
        Categoria(
          codigo: c['codigo'] as String,
          nombre: c['nombre'] as String,
          nota: c['nota'] as String?,
          tarjetas: [for (final t in (c['tarjetas'] as List)) Tarjeta.fromMap(t as Map<String, dynamic>)],
        )
    ];
    final grupos = {
      for (final g in (procedimientos['grupos'] as List))
        (g as Map)['id'] as String: GrupoProcedimiento(
            id: g['id'] as String, nombre: g['nombre'] as String, entrada: (g['entrada'] as num).toInt())
    };
    final nodos = <int, NodoProcedimiento>{};
    for (final e in (procedimientos['nodos'] as Map).entries) {
      final n = e.value as Map<String, dynamic>;
      nodos[int.parse(e.key as String)] = NodoProcedimiento(
        diapositiva: (n['diapositiva'] as num).toInt(),
        grupo: n['grupo'] as String,
        lineas: [for (final l in (n['lineas'] as List)) '$l'],
        opciones: [
          for (final o in (n['opciones'] as List))
            OpcionNodo(
              texto: (o as Map)['texto'] as String,
              destino: (o['destino'] as num?)?.toInt(),
              volver: o['volver'] as bool? ?? false,
              destinoInfo: DestinoRef.fromMap(o['destino_info'] as Map<String, dynamic>?),
            )
        ],
      );
    }
    final claves = {
      for (final e in (preguntasClave['por_tarjeta'] as Map).entries)
        e.key as String: [for (final q in (e.value as List)) PreguntaClave.fromMap(q as Map<String, dynamic>)]
    };
    return Protocolo._(categorias: cats, grupos: grupos, nodos: nodos, clavesPorTarjeta: claves);
  }
}
