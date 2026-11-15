import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/util/servicios_dispositivo.dart';
import '../auth/auth_service.dart';
import 'models.dart';
import 'reportes_repository.dart';

/// Reportes del ciudadano en tiempo real. Ademas de alimentar el historial,
/// compara cada actualizacion con la anterior para avisar con una
/// notificacion local cuando cambia el estado o llega una videollamada
/// (no se usan Cloud Functions ni FCM: ver DECISIONES.md).
class MisReportes extends ChangeNotifier {
  MisReportes({required this.auth, required this.repo, required this.notificaciones}) {
    auth.addListener(_alCambiarSesion);
    _alCambiarSesion();
  }

  final AuthService auth;
  final ReportesRepository repo;
  final NotificacionesService notificaciones;

  StreamSubscription<List<Reporte>>? _sub;
  String? _uid;
  List<Reporte> _lista = const [];
  bool _cargando = true;
  Object? _error;
  bool _primera = true;
  final Map<String, EstadoReporte> _estados = {};
  final Map<String, EstadoLlamada> _llamadas = {};

  /// Reporte con una videollamada entrante sin contestar.
  Reporte? llamadaEntrante;

  List<Reporte> get reportes => _lista;
  bool get cargando => _cargando;
  Object? get error => _error;

  Reporte? porRadicado(String id) {
    for (final r in _lista) {
      if (r.radicado == id) return r;
    }
    return null;
  }

  void _alCambiarSesion() {
    final uid = auth.uid;
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _lista = const [];
    _estados.clear();
    _llamadas.clear();
    _primera = true;
    llamadaEntrante = null;
    if (uid == null || auth.esOperador) {
      _cargando = uid == null;
      notifyListeners();
      return;
    }
    _cargando = true;
    _error = null;
    notifyListeners();
    _sub = repo.misReportes(uid).listen(_recibir, onError: (Object e) {
      _error = e;
      _cargando = false;
      notifyListeners();
    });
  }

  void reintentar() {
    _uid = null;
    _alCambiarSesion();
  }

  void _recibir(List<Reporte> nuevos) {
    for (final r in nuevos) {
      final antes = _estados[r.radicado];
      if (!_primera && antes != null && antes != r.estado) {
        notificaciones.mostrar(
          titulo: 'Su reporte ${r.radicado} cambió de estado',
          cuerpo: 'Ahora está: ${r.estado.etiqueta}.',
          payload: r.radicado,
        );
      }
      _estados[r.radicado] = r.estado;

      final llamAntes = _llamadas[r.radicado];
      final llamAhora = r.videollamada.estado;
      if (llamAhora == EstadoLlamada.llamando && llamAntes != EstadoLlamada.llamando) {
        llamadaEntrante = r;
        notificaciones.mostrar(
          titulo: 'Los Bomberos quieren hacer una videollamada',
          cuerpo: 'Reporte ${r.radicado}. Abra la aplicación para contestar.',
          payload: 'llamada:${r.radicado}',
          urgente: true,
        );
      } else if (llamAhora != EstadoLlamada.llamando && llamadaEntrante?.radicado == r.radicado) {
        llamadaEntrante = null;
      }
      _llamadas[r.radicado] = llamAhora;
    }
    _primera = false;
    _lista = nuevos;
    _cargando = false;
    _error = null;
    notifyListeners();
  }

  void descartarLlamada() {
    llamadaEntrante = null;
    notifyListeners();
  }

  @override
  void dispose() {
    auth.removeListener(_alCambiarSesion);
    _sub?.cancel();
    super.dispose();
  }
}
