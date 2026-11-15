import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/reportes/cola_offline.dart';
import '../../features/reportes/models.dart';
import 'geo.dart';

/// Guarda la cola como un archivo JSON en el almacenamiento privado de la app.
class ColaArchivoStorage implements ColaStorage {
  File? _f;

  Future<File> _archivo() async =>
      _f ??= File(p.join((await getApplicationSupportDirectory()).path, 'cola_reportes.json'));

  @override
  Future<String?> leer() async {
    final f = await _archivo();
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> escribir(String contenido) async {
    final f = await _archivo();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(contenido, flush: true);
    await tmp.rename(f.path);
  }
}

/// Resultado de pedir la ubicacion. Los fallos se distinguen para poder
/// explicar a la persona que hacer en cada caso.
sealed class ResultadoUbicacion {
  const ResultadoUbicacion();
}

class UbicacionObtenida extends ResultadoUbicacion {
  const UbicacionObtenida(this.ubicacion);
  final Ubicacion ubicacion;
}

enum FalloUbicacion { gpsApagado, permisoDenegado, permisoDenegadoParaSiempre, sinSenal }

class UbicacionFallida extends ResultadoUbicacion {
  const UbicacionFallida(this.fallo);
  final FalloUbicacion fallo;
}

class UbicacionService {
  Future<LocationPermission> permisoActual() => Geolocator.checkPermission();

  Future<ResultadoUbicacion> obtener({bool pedirPermiso = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const UbicacionFallida(FalloUbicacion.gpsApagado);
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && pedirPermiso) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return const UbicacionFallida(FalloUbicacion.permisoDenegadoParaSiempre);
    }
    if (perm == LocationPermission.denied) {
      return const UbicacionFallida(FalloUbicacion.permisoDenegado);
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 15),
        ),
      );
      return UbicacionObtenida(Ubicacion(lat: pos.latitude, lng: pos.longitude, precisionM: pos.accuracy));
    } catch (_) {
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null) {
        return UbicacionObtenida(
            Ubicacion(lat: ultima.latitude, lng: ultima.longitude, precisionM: ultima.accuracy));
      }
      return const UbicacionFallida(FalloUbicacion.sinSenal);
    }
  }

  Future<void> abrirAjustesUbicacion() => Geolocator.openLocationSettings();
}

/// Estado de la conexion para mostrar el aviso de "sin conexion".
class ConexionService extends ChangeNotifier {
  bool _enLinea = true;
  bool get enLinea => _enLinea;

  Future<void> iniciar() async {
    _enLinea = _hayRed(await Connectivity().checkConnectivity());
    Connectivity().onConnectivityChanged.listen((r) {
      final ahora = _hayRed(r);
      if (ahora != _enLinea) {
        _enLinea = ahora;
        notifyListeners();
        alCambiar?.call(ahora);
      }
    });
  }

  void Function(bool enLinea)? alCambiar;

  static bool _hayRed(List<ConnectivityResult> r) => r.any((e) => e != ConnectivityResult.none);
}

/// Identificador estable de la instalacion, para el limite de reportes.
class DispositivoService {
  DispositivoService(this._prefs);
  final SharedPreferences _prefs;

  String get id {
    var v = _prefs.getString('dispositivo_id');
    if (v == null) {
      final r = Random.secure();
      v = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      _prefs.setString('dispositivo_id', v);
    }
    return v;
  }

  List<DateTime> get envios => [
        for (final s in _prefs.getStringList('envios') ?? const <String>[])
          if (DateTime.tryParse(s) != null) DateTime.parse(s)
      ];

  Future<void> guardarEnvios(List<DateTime> v) =>
      _prefs.setStringList('envios', v.map((e) => e.toUtc().toIso8601String()).toList());

  String get nombreGuardado => _prefs.getString('ultimo_nombre') ?? '';
  String get telefonoGuardado => _prefs.getString('ultimo_telefono') ?? '';

  Future<void> recordarContacto(String nombre, String telefono) async {
    await _prefs.setString('ultimo_nombre', nombre);
    await _prefs.setString('ultimo_telefono', telefono);
  }
}

class NotificacionesService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;
  int _id = 100;

  Future<void> iniciar({void Function(String? payload)? alToque}) async {
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) => alToque?.call(r.payload),
    );
    _listo = true;
  }

  Future<bool> pedirPermiso() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<void> mostrar({required String titulo, required String cuerpo, String? payload, bool urgente = false}) async {
    if (!_listo) return;
    await _plugin.show(
      _id++,
      titulo,
      cuerpo,
      NotificationDetails(
        android: AndroidNotificationDetails(
          urgente ? 'llamada' : 'estado_reporte',
          urgente ? 'Videollamada de los Bomberos' : 'Estado de sus reportes',
          channelDescription: urgente
              ? 'Aviso cuando un radio operador quiere hacer una videollamada.'
              : 'Cambios de estado de los reportes que usted envió.',
          importance: urgente ? Importance.max : Importance.high,
          priority: urgente ? Priority.max : Priority.high,
          category: urgente ? AndroidNotificationCategory.call : null,
        ),
      ),
      payload: payload,
    );
  }
}

/// Abre apps externas: marcador de llamadas y Google Maps.
abstract final class Enlaces {
  static Future<bool> llamar(String numero) =>
      launchUrl(Uri(scheme: 'tel', path: numero), mode: LaunchMode.externalApplication);

  static Future<bool> mapa(double lat, double lng) =>
      launchUrl(enlaceGoogleMaps(lat, lng), mode: LaunchMode.externalApplication);

  static Future<bool> url(String u) => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
}

String jsonCorto(Object o) => const JsonEncoder().convert(o);

void logDebug(String m) {
  if (kDebugMode) debugPrint(m);
}
