import 'package:bomberos_cali/features/protocolo/protocolo.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final p = protocoloDeDisco();
  final todas = [for (final c in p.categorias) ...c.tarjetas];

  test('estan las siete categorias del protocolo', () {
    expect(p.categorias.map((c) => c.codigo), ['100', '200', '300', '400', '500', '800', '900']);
  });

  test('500, 800 y 900 no tienen tarjetas guia en el protocolo y no se inventan', () {
    for (final cod in ['500', '800', '900']) {
      final c = p.categoria(cod)!;
      expect(c.tarjetas, isEmpty);
      expect(c.nota, contains('no incluye tarjetas'));
    }
  });

  test('extrae 65 tarjetas con preguntas, despacho y pre-arribo', () {
    expect(todas, hasLength(65));
    expect(p.categoria('100')!.tarjetas, hasLength(16));
    expect(p.categoria('200')!.tarjetas, hasLength(2));
    expect(p.categoria('300')!.tarjetas, hasLength(40));
    expect(p.categoria('400')!.tarjetas, hasLength(7));
    for (final t in todas) {
      expect(t.preguntas, isNotEmpty, reason: '${t.id} sin preguntas');
      expect(t.preArribo, isNotEmpty, reason: '${t.id} sin pre-arribo');
      expect(t.preArribo.first.lineas, isNotEmpty, reason: '${t.id} pre-arribo vacio');
      expect(t.despacho, isNotEmpty, reason: '${t.id} sin despacho');
    }
  });

  test('no quedo texto vertical decorativo (P R E G U N T A S) ni el letrero de no cuelgue', () {
    final vertical = RegExp(r'^(\S ){4,}\S$');
    void revisar(String s, String donde) {
      expect(vertical.hasMatch(s.trim()), isFalse, reason: '$donde: "$s"');
      expect(s.toUpperCase(), isNot(startsWith('NO CUELGUE')), reason: donde);
      expect(s.toLowerCase(), isNot('siga a instrucciones pre-arribo'), reason: donde);
    }

    for (final t in todas) {
      for (final q in t.preguntas) {
        revisar(q, t.id);
      }
      for (final s in t.preArribo) {
        for (final l in s.lineas) {
          revisar(l, t.id);
        }
      }
      for (final d in t.despacho) {
        revisar(d.descripcion, t.id);
      }
    }
    for (final n in p.nodos.values) {
      for (final l in n.lineas) {
        revisar(l, 'nodo ${n.diapositiva}');
      }
    }
  });

  test('conserva el texto del protocolo tal cual (muestras)', () {
    final ojos = p.tarjeta('ojos')!;
    expect(ojos.preguntas, contains('¿Qué causó la lesión?'));
    final trans = p.tarjeta('accidente_transito')!;
    expect(trans.numero, 29);
    expect(trans.preArribo.first.lineas,
        contains('No le dé nada de comer o beber a la persona herida, ni siquiera agua.'));
    expect(p.tarjeta('hemorragia')!.preArribo.first.lineas.join(' '), contains('NO USE HIELO'));
    final cultivos = p.tarjeta('incendio_cultivos')!;
    expect(cultivos.despacho.map((d) => d.codigo), containsAll(['171', '172', '173', '170']));
  });

  test('los codigos de despacho son de tres digitos', () {
    for (final t in todas) {
      for (final d in t.despacho) {
        if (d.codigo != null) expect(d.codigo, matches(RegExp(r'^\d{3}$')), reason: t.id);
      }
    }
    String? primero(String id) => p.tarjeta(id)!.despacho.map((d) => d.codigo).whereType<String>().first;
    expect(primero('dolor_pecho'), '321');
    expect(primero('fuga_gas'), '412');
  });

  test('las referencias entre tarjetas se resuelven a un destino que existe', () {
    var total = 0;
    void revisar(Referencia r, String donde) {
      final d = r.destino;
      if (d == null) return;
      total++;
      if (d.esTarjeta) expect(p.tarjeta(d.id), isNotNull, reason: '$donde -> ${d.id}');
      if (d.esProcedimiento) {
        expect(p.nodos.containsKey(d.nodo), isTrue, reason: '$donde -> nodo ${d.nodo}');
        expect(p.grupos.containsKey(d.grupo), isTrue);
      }
    }

    for (final t in todas) {
      for (final r in t.referencias) {
        revisar(r, t.id);
      }
      for (final s in t.preArribo) {
        for (final r in s.referencias) {
          revisar(r, t.id);
        }
      }
    }
    expect(total, greaterThan(50));
  });

  test('"Ataque cardiaco" enlaza a las tres tarjetas de RCP por edad', () {
    final refs = p.tarjeta('ataque_cardiaco')!.preArribo.first.referencias;
    final grupos = refs.map((r) => r.destino?.grupo).toSet();
    expect(grupos, containsAll(['rcp_adulto', 'rcp_nino', 'rcp_infante']));
  });

  test('los procedimientos forman un grafo navegable', () {
    expect(p.grupos.keys, containsAll(['rcp_adulto', 'rcp_nino', 'rcp_infante', 'parto', 'ovace_adulto', 'torniquete']));
    final rcp = p.nodos[p.grupos['rcp_adulto']!.entrada]!;
    expect(rcp.lineas.single, '¿Alguien en el sitio sabe dar RCP?');
    expect(rcp.opciones.map((o) => o.texto), ['NO', 'SI']);
    for (final n in p.nodos.values) {
      for (final o in n.opciones) {
        if (o.destino != null) expect(p.nodos.containsKey(o.destino) || o.destinoInfo != null, isTrue, reason: 'nodo ${n.diapositiva}');
      }
    }
  });

  group('cuestionario corto', () {
    const medicas = {'consciente', 'respira', 'edad_sexo'};

    test('es corto: maximo 5 preguntas en tarjetas medicas y 3 en las demas', () {
      for (final t in todas) {
        final q = p.clavesDe(t.id);
        final medica = q.any((x) => medicas.contains(x.clave));
        expect(q.length, lessThanOrEqualTo(medica ? 5 : 3), reason: t.id);
      }
    });

    test('cada pregunta es una oracion literal del protocolo (no se inventa nada)', () {
      final general = [
        '¿El paciente está consciente (es capaz de hablar)?',
        '¿El paciente respira de forma normal?',
        '¿Sexo y edad del paciente?',
      ];
      String plano(String s) => s.replaceAll('¿', '').replaceAll('¡', '');
      var revisadas = 0;
      for (final t in todas) {
        final texto = plano(t.preguntas.join(' \n '));
        for (final q in p.clavesDe(t.id)) {
          revisadas++;
          if (medicas.contains(q.clave)) {
            expect(general, contains(q.texto), reason: '${t.id}/${q.clave}');
          } else {
            expect(texto, contains(plano(q.texto)), reason: '${t.id}/${q.clave}: ${q.texto}');
          }
        }
      }
      expect(revisadas, greaterThan(150));
    });

    test('las tarjetas medicas incluyen consciencia y respiracion', () {
      for (final id in ['caidas', 'ataque_cardiaco', 'dolor_pecho', 'trauma']) {
        final claves = p.clavesDe(id).map((q) => q.clave);
        expect(claves, containsAll(['consciente', 'respira']), reason: id);
      }
    });

    test('rescates como Extraviado en zona rural no tienen preguntas que una foto no responda', () {
      expect(p.clavesDe('extraviado_zona_rural'), isEmpty);
    });
  });
}
