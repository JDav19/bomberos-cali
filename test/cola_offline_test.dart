import 'package:bomberos_cali/features/reportes/cola_offline.dart';
import 'package:bomberos_cali/features/reportes/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late AlmacenFalso almacen;
  late BackendFalso backend;
  late DateTime ahora;
  late ColaOffline cola;

  ColaOffline nueva() => ColaOffline(storage: almacen, backend: backend, reloj: () => ahora);

  setUp(() {
    almacen = AlmacenFalso();
    backend = BackendFalso();
    ahora = DateTime.utc(2026, 11, 19, 15);
    cola = nueva();
  });

  tearDown(() => cola.dispose());

  test('sin red el reporte queda guardado y no se pierde', () async {
    backend.enLinea = false;
    await cola.encolar(reporteDe(), [ArchivoPendiente(ruta: 'a', tipo: TipoMedia.foto)]);
    await cola.procesar(ignorarEspera: true);

    expect(cola.pendientes, 1);
    expect(backend.creados, isEmpty);
    expect(cola.items.single.documentoEnviado, isFalse);
    // Y sobrevive a cerrar la app: se recarga desde el almacenamiento.
    final otra = nueva();
    await otra.cargar();
    expect(otra.pendientes, 1);
    expect(otra.items.single.archivos.single.ruta, 'a');
    otra.dispose();
  });

  test('al volver la red se envia primero el reporte y despues los archivos', () async {
    backend.enLinea = false;
    await cola.encolar(reporteDe(), [
      ArchivoPendiente(ruta: 'a', tipo: TipoMedia.foto),
      ArchivoPendiente(ruta: 'b', tipo: TipoMedia.video),
    ]);
    await cola.procesar(ignorarEspera: true);
    backend.enLinea = true;
    await cola.procesar(ignorarEspera: true);

    expect(backend.orden, ['doc', 'archivo', 'archivo']);
    expect(backend.mediaAgregada, hasLength(2));
    expect(cola.pendientes, 0);
  });

  test('si falla la subida de archivos el reporte ya llego y se reintenta solo la subida', () async {
    backend.fallaSubida = true;
    await cola.encolar(reporteDe(), [ArchivoPendiente(ruta: 'a', tipo: TipoMedia.foto)]);
    await cola.procesar(ignorarEspera: true);

    expect(backend.creados, ['BC-261119-AAAAA']);
    expect(cola.pendientes, 1);
    expect(cola.items.single.documentoEnviado, isTrue);

    backend.fallaSubida = false;
    await cola.procesar(ignorarEspera: true);
    expect(backend.creados, hasLength(1), reason: 'no vuelve a crear el reporte');
    expect(backend.mediaAgregada, hasLength(1));
    expect(cola.pendientes, 0);
  });

  test('respeta la espera de reintento y la salta si se pide', () async {
    backend.enLinea = false;
    await cola.encolar(reporteDe(), const []);
    await cola.procesar(ignorarEspera: true);
    final espera = cola.items.single.proximoIntento!;
    expect(espera.isAfter(ahora), isTrue);

    backend.enLinea = true;
    await cola.procesar(); // aun no es el turno
    expect(backend.creados, isEmpty);

    ahora = espera.add(const Duration(seconds: 1));
    await cola.procesar();
    expect(backend.creados, hasLength(1));
    expect(cola.pendientes, 0);
  });

  test('retroceso exponencial con tope de 5 minutos', () {
    expect(esperaReintento(1), const Duration(seconds: 5));
    expect(esperaReintento(2), const Duration(seconds: 10));
    expect(esperaReintento(3), const Duration(seconds: 20));
    expect(esperaReintento(6), const Duration(seconds: 160));
    expect(esperaReintento(7), const Duration(minutes: 5));
    expect(esperaReintento(30), const Duration(minutes: 5));
  });

  test('un archivo invalido se descarta sin frenar el reporte ni los demas archivos', () async {
    backend.subidaPermanente = true;
    await cola.encolar(reporteDe(), [ArchivoPendiente(ruta: 'a', tipo: TipoMedia.foto)]);
    await cola.procesar(ignorarEspera: true);

    expect(backend.creados, hasLength(1));
    expect(backend.descartes, 1);
    expect(cola.pendientes, 0);
  });

  test('tras el maximo de intentos un archivo se descarta pero el reporte queda enviado', () async {
    backend.fallaSubida = true;
    final c = ColaOffline(storage: almacen, backend: backend, reloj: () => ahora, maxIntentosArchivo: 3);
    await c.encolar(reporteDe(), [ArchivoPendiente(ruta: 'a', tipo: TipoMedia.foto)]);
    for (var i = 0; i < 3; i++) {
      await c.procesar(ignorarEspera: true);
    }
    expect(backend.intentosSubida, 3);
    expect(backend.descartes, 1);
    expect(c.pendientes, 0);
    expect(backend.creados, hasLength(1));
    c.dispose();
  });

  test('las respuestas del cuestionario se agregan al reporte que aun esta en la cola', () async {
    backend.enLinea = false;
    final r = reporteDe();
    await cola.encolar(r, const []);
    final ok = await cola.reemplazarSiPendiente(r.copyWith(respuestas: {'consciente': 'si'}, cuestionarioCompleto: true));
    expect(ok, isTrue);
    expect(cola.items.single.reporte.respuestas['consciente'], 'si');

    backend.enLinea = true;
    await cola.procesar(ignorarEspera: true);
    // Ya enviado: no se puede reemplazar en la cola.
    expect(await cola.reemplazarSiPendiente(r), isFalse);
  });

  test('un archivo de cola danado no impide abrir la app', () async {
    almacen.contenido = '{esto no es json';
    await cola.cargar();
    expect(cola.pendientes, 0);
  });
}
