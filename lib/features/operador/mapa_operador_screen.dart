import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/widgets/comunes.dart';
import '../reportes/agrupacion.dart';
import '../reportes/models.dart';
import 'detalle_operador_screen.dart';
import 'operador_controller.dart';

/// Mapa con todos los reportes activos. Los circulos naranja marcan los
/// grupos de reportes cercanos (posible mismo incidente).
class MapaOperadorScreen extends StatefulWidget {
  const MapaOperadorScreen({super.key});

  @override
  State<MapaOperadorScreen> createState() => _MapaOperadorScreenState();
}

class _MapaOperadorScreenState extends State<MapaOperadorScreen> {
  static const _cali = LatLng(3.4516, -76.5320);
  GoogleMapController? _mapa;
  bool _encuadrado = false;

  static double _tono(Prioridad p) => switch (p) {
        Prioridad.critica => BitmapDescriptor.hueRed,
        Prioridad.alta => BitmapDescriptor.hueOrange,
        Prioridad.media => BitmapDescriptor.hueYellow,
        Prioridad.baja => BitmapDescriptor.hueAzure,
      };

  void _encuadrar(List<Reporte> rs) {
    final puntos = [for (final r in rs) if (r.ubicacion != null) LatLng(r.ubicacion!.lat, r.ubicacion!.lng)];
    final m = _mapa;
    if (m == null || puntos.isEmpty || _encuadrado) return;
    _encuadrado = true;
    if (puntos.length == 1) {
      m.animateCamera(CameraUpdate.newLatLngZoom(puntos.first, 15));
      return;
    }
    var sur = puntos.first.latitude, norte = sur, oeste = puntos.first.longitude, este = oeste;
    for (final p in puntos) {
      if (p.latitude < sur) sur = p.latitude;
      if (p.latitude > norte) norte = p.latitude;
      if (p.longitude < oeste) oeste = p.longitude;
      if (p.longitude > este) este = p.longitude;
    }
    m.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(sur, oeste), northeast: LatLng(norte, este)), 60));
  }

  void _resumen(Reporte r) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.l),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.tarjetaNombre ?? r.categoriaNombre, style: t.headlineSmall)),
                InsigniaPrioridad(r.prioridad),
              ]),
              const SizedBox(height: Space.xs),
              Text('${r.radicado} · ${hace(r.creadoEn)}', style: t.bodyMedium),
              const SizedBox(height: Space.s),
              ChipEstado(r.estado),
              const SizedBox(height: Space.l),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => DetalleOperadorScreen(radicado: r.radicado)));
                },
                child: const Text('ABRIR REPORTE'),
              ),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperadorController>();
    final activos = c.activos.where((r) => r.ubicacion != null).toList();
    final grupos = agruparReportes(activos).where((g) => g.esPosibleIncidente);

    final marcadores = {
      for (final r in activos)
        Marker(
          markerId: MarkerId(r.radicado),
          position: LatLng(r.ubicacion!.lat, r.ubicacion!.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(_tono(r.prioridad)),
          infoWindow: InfoWindow(title: r.tarjetaNombre ?? r.categoriaNombre, snippet: r.prioridad.etiqueta),
          onTap: () => _resumen(r),
        ),
    };
    final circulos = {
      for (final g in grupos)
        if (g.centro != null)
          Circle(
            circleId: CircleId('g${g.reportes.first.radicado}'),
            center: LatLng(g.centro!.lat, g.centro!.lng),
            radius: radioAgrupacionM,
            fillColor: Palette.brasa.withValues(alpha: 0.18),
            strokeColor: Palette.brasaOscura,
            strokeWidth: 2,
          ),
    };

    return Stack(children: [
      GoogleMap(
        initialCameraPosition: const CameraPosition(target: _cali, zoom: 12),
        markers: marcadores,
        circles: circulos,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        onMapCreated: (m) {
          _mapa = m;
          _encuadrar(activos);
        },
      ),
      Positioned(
        left: Space.l,
        top: Space.l,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
          decoration: BoxDecoration(color: Palette.ceniza, borderRadius: Radii.card, boxShadow: Elevations.card),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const PhosphorIcon(PhosphorIconsBold.mapPin, size: 18, color: Palette.oxido),
            const SizedBox(width: Space.s),
            Text('${activos.length} activos en el mapa', style: Theme.of(context).textTheme.labelLarge),
          ]),
        ),
      ),
      Positioned(
        right: Space.l,
        bottom: Space.l,
        child: FloatingActionButton.small(
          backgroundColor: Palette.ceniza,
          foregroundColor: Palette.carbon,
          elevation: 2,
          tooltip: 'Ver todos los reportes',
          onPressed: () {
            _encuadrado = false;
            _encuadrar(activos);
          },
          child: const PhosphorIcon(PhosphorIconsBold.arrowsOutSimple),
        ),
      ),
    ]);
  }
}
