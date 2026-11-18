import 'package:bomberos_cali/features/reportes/cola_offline.dart';
import 'package:bomberos_cali/features/reportes/models.dart';
import 'package:bomberos_cali/features/reportes/reportes_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('Mas archivos en un reporte ya creado (cola)', () {
    late AlmacenFalso almacen;
    late BackendFalso backend;
    late ColaOffline cola;

    setUp(() {
      almacen = AlmacenFalso();
      backend = BackendFalso();
      cola = ColaOffline(storage: almacen, backend: backend, reloj: () => DateTime.utc(2026, 11, 19, 15));
    });
    tearDown(() => cola.dispose());

    test('si el reporte ya llego a la nube, se crea un item solo de archivos', () async {
      final r = reporteDe();
      final remoto = await cola.agregarArchivos(r, [ArchivoPendiente(ruta: 'b', tipo: TipoMedia.foto)]);
      expect(remoto, isTrue, reason: 'hay que sumar el pendiente en el documento remoto');
      expect(cola.items.single.documentoEnviado, isTrue);

      await cola.procesar(ignorarEspera: true);
      expect(backend.creados, isEmpty, reason: 'no se vuelve a crear el reporte');
      expect(backend.mediaAgregada, hasLength(1));
      expect(cola.pendientes, 0);
    });

    test('si el reporte sigue en el telefono, los archivos se suman a ese item y al contador', () async {
      backend.enLinea = false;
      final r = reporteDe().copyWith(mediaPendiente: 1);
      await cola.encolar(r, [ArchivoPendiente(ruta: 'a', tipo: TipoMedia.foto)]);

      final remoto = await cola.agregarArchivos(r, [ArchivoPendiente(ruta: 'b', tipo: TipoMedia.video)]);
      expect(remoto, isFalse, reason: 'el contador viaja dentro del reporte, no hay documento remoto');
      expect(cola.items.single.archivos, hasLength(2));
      expect(cola.items.single.reporte.mediaPendiente, 2);

      backend.enLinea = true;
      await cola.procesar(ignorarEspera: true);
      expect(backend.creados, hasLength(1));
      expect(backend.mediaAgregada, hasLength(2));
      expect(backend.orden.first, 'doc');
    });

    test('los archivos agregados sobreviven a cerrar la app', () async {
      backend.enLinea = false;
      await cola.agregarArchivos(reporteDe(), [ArchivoPendiente(ruta: 'b', tipo: TipoMedia.foto)]);
      final otra = ColaOffline(storage: almacen, backend: backend, reloj: () => DateTime.utc(2026, 11, 19, 15));
      await otra.cargar();
      expect(otra.items.single.archivos.single.ruta, 'b');
      otra.dispose();
    });
  });

  group('Repositorio con Firestore simulado', () {
    late FakeFirebaseFirestore db;
    late ReportesRepository repo;

    setUp(() async {
      db = FakeFirebaseFirestore();
      repo = ReportesRepository(db, subir: (a) async => throw UnimplementedError());
      await repo.crearReporte(reporteDe(categoria: '900', tarjetaId: null, prioridad: Prioridad.media));
    });

    test('actualizarDetalles cambia tipo, texto y contacto sin tocar ubicacion ni estado', () async {
      final r = reporteDe(categoria: '900', tarjetaId: null, prioridad: Prioridad.media).copyWith(
        categoria: '100',
        categoriaNombre: 'Incendios',
        tarjetaId: 'incendio_edificio_alto',
        tarjetaNombre: 'Incendio en edificio alto',
        descripcion: 'Humo en el piso 3',
        referencia: 'Frente al parque',
        nombre: 'Luis',
        telefono: '3109998877',
        prioridad: Prioridad.critica,
      );
      await repo.actualizarDetalles(r);

      final d = (await db.collection('reportes').doc(r.radicado).get()).data()!;
      expect(d['categoria'], '100');
      expect(d['tarjetaId'], 'incendio_edificio_alto');
      expect(d['descripcion'], 'Humo en el piso 3');
      expect(d['nombre'], 'Luis');
      expect(d['prioridad'], 'critica');
      expect(d['prioridadPeso'], 0);
      expect(d['estado'], 'recibido');
      expect((d['ubicacion'] as Map)['lat'], 3.4516);
    });

    test('sumarPendientes y agregarMedia llevan la cuenta de archivos en camino', () async {
      final id = reporteDe().radicado;
      await repo.sumarPendientes(id, 2);
      var d = (await db.collection('reportes').doc(id).get()).data()!;
      expect(d['mediaPendiente'], 2);

      await repo.agregarMedia(id, const MediaItem(url: 'https://res.cloudinary.com/x/image/upload/a.jpg', tipo: TipoMedia.foto));
      d = (await db.collection('reportes').doc(id).get()).data()!;
      expect(d['mediaPendiente'], 1);
      expect(d['media'], hasLength(1));
    });

    test('cambiarEstado guarda el estado nuevo y quien lo cambio', () async {
      final id = reporteDe().radicado;
      await repo.cambiarEstado(id, EstadoReporte.despachado, 'op1');
      final d = (await db.collection('reportes').doc(id).get()).data()!;
      expect(d['estado'], 'despachado');
      expect(d['operadorUid'], 'op1');
    });
  });
}
