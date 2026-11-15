import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/util/servicios_dispositivo.dart';
import 'features/auth/auth_service.dart';
import 'features/ciudadano/configuracion_pendiente.dart';
import 'features/protocolo/protocolo.dart';
import 'features/reportes/cola_offline.dart';
import 'features/reportes/envio_controller.dart';
import 'features/reportes/media_service.dart';
import 'features/reportes/mis_reportes.dart';
import 'features/reportes/reportes_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO');
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  if (!AppConfig.firebaseListo) {
    runApp(ConfiguracionPendienteApp(faltantes: AppConfig.faltantes()));
    return;
  }

  await Firebase.initializeApp(options: AppConfig.firebaseOptions);
  final prefs = await SharedPreferences.getInstance();
  final protocolo = await Protocolo.cargar(rootBundle);

  final auth = AuthService(FirebaseAuth.instance, FirebaseFirestore.instance);
  final conexion = ConexionService();
  final notificaciones = NotificacionesService();
  final media = MediaService();
  final repo = ReportesRepository(FirebaseFirestore.instance, subir: media.subir);
  final cola = ColaOffline(storage: ColaArchivoStorage(), backend: repo);
  final dispositivo = DispositivoService(prefs);
  final envio = EnvioController(auth: auth, cola: cola, repo: repo, media: media, dispositivo: dispositivo);
  final misReportes = MisReportes(auth: auth, repo: repo, notificaciones: notificaciones);

  await Future.wait([conexion.iniciar(), cola.cargar(), notificaciones.iniciar(alToque: App.alTocarNotificacion)]);
  // Al volver la red se vacia la cola; tambien al abrir la app.
  conexion.alCambiar = (enLinea) {
    if (enLinea) cola.procesar(ignorarEspera: true);
  };
  await auth.iniciar();
  cola.procesar(ignorarEspera: true);

  runApp(MultiProvider(
    providers: [
      Provider<Protocolo>.value(value: protocolo),
      ChangeNotifierProvider<AuthService>.value(value: auth),
      ChangeNotifierProvider<ConexionService>.value(value: conexion),
      ChangeNotifierProvider<ColaOffline>.value(value: cola),
      ChangeNotifierProvider<EnvioController>.value(value: envio),
      ChangeNotifierProvider<MisReportes>.value(value: misReportes),
      Provider<ReportesRepository>.value(value: repo),
      Provider<DispositivoService>.value(value: dispositivo),
      Provider<NotificacionesService>.value(value: notificaciones),
      Provider<UbicacionService>(create: (_) => UbicacionService()),
    ],
    child: const App(),
  ));
}
