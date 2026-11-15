import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../reportes/agrupacion.dart';
import '../reportes/models.dart';
import '../reportes/reportes_repository.dart';

enum FiltroBandeja { activos, todos }

/// Un elemento de la bandeja: un reporte suelto o un grupo de reportes
/// cercanos en distancia y tiempo (posible mismo incidente).
class ElementoBandeja {
  ElementoBandeja(this.grupo);
  final GrupoReportes grupo;
  bool get esGrupo => grupo.esPosibleIncidente;
  Reporte get principal => grupo.reportes.reduce(_masUrgente);

  static Reporte _masUrgente(Reporte a, Reporte b) {
    final c = a.prioridad.peso.compareTo(b.prioridad.peso);
    if (c != 0) return c < 0 ? a : b;
    return a.creadoEn.isBefore(b.creadoEn) ? a : b;
  }
}

/// Reportes de toda la ciudad en tiempo real para el radio operador.
class OperadorController extends ChangeNotifier {
  OperadorController({required this.repo, required this.auth}) {
    _escuchar();
  }

  void _escuchar() {
    _sub?.cancel();
    _sub = repo.todos().listen(_recibir, onError: (Object e) {
      _error = e;
      _cargando = false;
      notifyListeners();
    });
  }

  void reintentar() {
    _cargando = true;
    _error = null;
    notifyListeners();
    _escuchar();
  }

  final ReportesRepository repo;
  final AuthService auth;

  StreamSubscription<List<Reporte>>? _sub;
  List<Reporte> _todos = const [];
  bool _cargando = true;
  Object? _error;
  bool _primera = true;
  final Set<String> _vistos = {};
  FiltroBandeja filtro = FiltroBandeja.activos;

  /// Se llama cuando llega un reporte nuevo despues de la carga inicial.
  void Function(Reporte nuevo)? alNuevo;

  List<Reporte> get todos => _todos;
  bool get cargando => _cargando;
  Object? get error => _error;

  List<Reporte> get activos => _todos.where((r) => r.estado.activo).toList();

  List<Reporte> get visibles => filtro == FiltroBandeja.activos ? activos : _todos;

  /// Elementos ordenados por prioridad y despues por antiguedad (el que mas
  /// lleva esperando primero).
  List<ElementoBandeja> get bandeja {
    final grupos = agruparReportes(visibles.where((r) => r.estado.activo).toList());
    final inactivos = visibles.where((r) => !r.estado.activo).map((r) => GrupoReportes([r]));
    final items = [...grupos, ...inactivos].map(ElementoBandeja.new).toList();
    for (final e in items) {
      e.grupo.reportes.sort((a, b) {
        final c = a.prioridad.peso.compareTo(b.prioridad.peso);
        return c != 0 ? c : a.creadoEn.compareTo(b.creadoEn);
      });
    }
    items.sort((a, b) {
      final ai = a.principal.estado.activo ? 0 : 1;
      final bi = b.principal.estado.activo ? 0 : 1;
      if (ai != bi) return ai.compareTo(bi);
      final c = a.grupo.prioridad.peso.compareTo(b.grupo.prioridad.peso);
      return c != 0 ? c : a.grupo.primero.compareTo(b.grupo.primero);
    });
    return items;
  }

  Reporte? porRadicado(String id) {
    for (final r in _todos) {
      if (r.radicado == id) return r;
    }
    return null;
  }

  void cambiarFiltro(FiltroBandeja f) {
    filtro = f;
    notifyListeners();
  }

  void _recibir(List<Reporte> l) {
    if (!_primera) {
      for (final r in l) {
        if (!_vistos.contains(r.radicado)) alNuevo?.call(r);
      }
    }
    _vistos.addAll(l.map((r) => r.radicado));
    _primera = false;
    _todos = l;
    _cargando = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
