import 'dart:convert';
import 'dart:math';

import 'package:bomberos_cali/core/util/formatters.dart';
import 'package:bomberos_cali/features/reportes/limite_reportes.dart';
import 'package:bomberos_cali/features/reportes/models.dart';
import 'package:bomberos_cali/features/reportes/prioridad.dart';
import 'package:bomberos_cali/features/reportes/radicado.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('Reporte', () {
    test('ida y vuelta por JSON local (cola offline) conserva todos los campos', () {
      final r = reporteDe().copyWith(
        respuestas: {'consciente': 'si', 'respira': 'no'},
        cuestionarioCompleto: true,
        mediaPendiente: 2,
        media: [const MediaItem(url: 'https://res.cloudinary.com/x/image/upload/v1/a.jpg', tipo: TipoMedia.foto, bytes: 300)],
        videollamada: Videollamada(estado: EstadoLlamada.llamando, canal: 'c', creadaEn: DateTime.utc(2026, 11, 19)),
        historial: [CambioEstado(estado: EstadoReporte.recibido, en: DateTime.utc(2026, 11, 19, 15))],
      );
      final copia = Reporte.fromMap(json.decode(json.encode(r.toMap(firestore: false))) as Map<String, dynamic>);

      expect(copia.radicado, r.radicado);
      expect(copia.ubicacion!.lat, r.ubicacion!.lat);
      expect(copia.ubicacion!.precisionM, 12);
      expect(copia.respuestas, r.respuestas);
      expect(copia.cuestionarioCompleto, isTrue);
      expect(copia.media.single.bytes, 300);
      expect(copia.mediaPendiente, 2);
      expect(copia.videollamada.estado, EstadoLlamada.llamando);
      expect(copia.historial.single.estado, EstadoReporte.recibido);
      expect(copia.creadoEn.toUtc(), r.creadoEn.toUtc());
      expect(copia.prioridad, Prioridad.alta);
    });

    test('guarda el peso de prioridad para ordenar y las coordenadas como numeros', () {
      final m = reporteDe(prioridad: Prioridad.critica).toMap(firestore: false);
      expect(m['prioridadPeso'], 0);
      expect((m['ubicacion'] as Map)['lat'], 3.4516);
    });

    test('un documento con campos faltantes no rompe la lectura', () {
      final r = Reporte.fromMap({'radicado': 'X', 'uid': 'u', 'creadoEn': '2026-11-19T15:00:00Z'});
      expect(r.estado, EstadoReporte.recibido);
      expect(r.prioridad, Prioridad.media);
      expect(r.media, isEmpty);
      expect(r.ubicacion, isNull);
      expect(r.videollamada.estado, EstadoLlamada.ninguna);
    });

    test('estados: activos y cerrados', () {
      expect(EstadoReporte.recibido.activo, isTrue);
      expect(EstadoReporte.despachado.activo, isTrue);
      expect(EstadoReporte.atendido.activo, isFalse);
      expect(EstadoReporte.cerrado.activo, isFalse);
      expect(EstadoReporte.desde('cosa rara'), EstadoReporte.recibido);
    });

    test('la miniatura de un video pide un fotograma .jpg a Cloudinary', () {
      const v = MediaItem(url: 'https://res.cloudinary.com/x/video/upload/v1/reportes/abc.mp4', tipo: TipoMedia.video);
      expect(v.miniatura, endsWith('/reportes/abc.jpg'));
      expect(v.miniatura, contains('so_0'));
    });

    test('subir prioridad nunca pasa de critica', () {
      expect(Prioridad.baja.subir(1), Prioridad.media);
      expect(Prioridad.alta.subir(5), Prioridad.critica);
    });
  });

  group('Radicado', () {
    test('tiene el formato BC-AAMMDD-XXXXXXX y es valido', () {
      final r = generarRadicado(DateTime(2026, 11, 19, 10), Random(1));
      expect(r, matches(RegExp(r'^BC-261119-[A-Z2-9]{7}$')));
      expect(radicadoValido(r), isTrue);
      expect(radicadoValido('BC-261119-0OIL1AB'), isFalse);
    });

    test('no repite en 50.000 generaciones', () {
      final rng = Random(7);
      final s = {for (var i = 0; i < 50000; i++) generarRadicado(DateTime(2026, 11, 19), rng)};
      expect(s.length, 50000);
    });
  });

  group('Limite de reportes', () {
    const limite = LimiteReportes();
    final ahora = DateTime.utc(2026, 11, 19, 15, 30);

    test('permite hasta 3 en 10 minutos y bloquea el cuarto', () {
      final envios = [for (final m in [1, 4, 8]) ahora.subtract(Duration(minutes: m))];
      expect(limite.permite(envios.sublist(0, 2), ahora), isTrue);
      expect(limite.permite(envios, ahora), isFalse);
    });

    test('dice cuanto falta para poder enviar otro', () {
      final envios = [for (final m in [1, 4, 8]) ahora.subtract(Duration(minutes: m))];
      // El mas antiguo cumple 10 min dentro de 2 min.
      expect(limite.esperar(envios, ahora), const Duration(minutes: 2));
      expect(limite.esperar(const [], ahora), isNull);
    });

    test('los envios viejos dejan de contar', () {
      final envios = [for (final m in [11, 12, 30]) ahora.subtract(Duration(minutes: m))];
      expect(limite.permite(envios, ahora), isTrue);
      expect(limite.podar(envios, ahora), isEmpty);
    });
  });

  group('Prioridad automatica', () {
    test('parte de la tarjeta y la categoria', () {
      expect(prioridadBase('300', 'ataque_cardiaco'), Prioridad.critica);
      expect(prioridadBase('300', 'caidas'), Prioridad.alta);
      expect(prioridadBase('300', 'dolor_cabeza'), Prioridad.media);
      expect(prioridadBase('400', null), Prioridad.media);
      expect(prioridadBase('500', null), Prioridad.baja);
      expect(prioridadBase('100', 'incendio_edificio_alto'), Prioridad.critica);
    });

    test('persona inconsciente o que no respira pasa a critica', () {
      final p = protocoloDeDisco();
      final claves = p.clavesDe('caidas');
      expect(calcularPrioridad(categoria: '300', tarjetaId: 'caidas', respuestas: {'consciente': 'no'}, claves: claves),
          Prioridad.critica);
      expect(calcularPrioridad(categoria: '300', tarjetaId: 'caidas', respuestas: {'respira': 'no'}, claves: claves),
          Prioridad.critica);
      expect(calcularPrioridad(categoria: '300', tarjetaId: 'caidas', respuestas: {'consciente': 'si', 'respira': 'si'}, claves: claves),
          Prioridad.alta);
    });

    test('atrapados, mas de 3 heridos y sangrado suben un nivel', () {
      final p = protocoloDeDisco();
      final claves = p.clavesDe('accidente_transito');
      expect(
          calcularPrioridad(
              categoria: '300', tarjetaId: 'accidente_transito', respuestas: {'atrapados': 'si'}, claves: claves),
          Prioridad.critica);
      expect(
          calcularPrioridad(
              categoria: '300', tarjetaId: 'accidente_transito', respuestas: {'heridos_numero': '4'}, claves: claves),
          Prioridad.critica);
      expect(
          calcularPrioridad(
              categoria: '300', tarjetaId: 'accidente_transito', respuestas: {'heridos_numero': '1'}, claves: claves),
          Prioridad.alta);
    });

    test('sin respuestas queda la prioridad base', () {
      expect(calcularPrioridad(categoria: '100', tarjetaId: 'incendio_bosque'), Prioridad.alta);
    });
  });

  group('Formato', () {
    test('telefono colombiano', () {
      expect(validarTelefono('3001234567'), isNull);
      expect(validarTelefono('+57 300 123 4567'), isNull);
      expect(validarTelefono('6024445566'), isNull);
      expect(validarTelefono('12345'), isNotNull);
      expect(validarTelefono(''), isNotNull);
      expect(normalizarTelefono('+57 300 123 4567'), '3001234567');
    });

    test('corrige solo los signos de apertura omitidos en el protocolo', () {
      expect(textoPregunta('El paciente está sangrando mucho?'), '¿El paciente está sangrando mucho?');
      expect(textoPregunta('¿alguien está atrapado en el vehículo?'), '¿Alguien está atrapado en el vehículo?');
      expect(textoPregunta('¿Hay alguien lesionado?'), '¿Hay alguien lesionado?');
    });
  });
}
