import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/estilos.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/util/servicios_dispositivo.dart';
import '../../core/widgets/categorias_ui.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/estados.dart';
import '../../core/widgets/galeria.dart';
import '../../core/widgets/marca.dart';
import '../auth/auth_service.dart';
import '../protocolo/protocolo.dart';
import '../reportes/models.dart';
import '../reportes/reportes_repository.dart';
import '../videollamada/videollamada_screen.dart';

/// Detalle para el radio operador: ubicacion exacta, fotos y videos, datos del
/// ciudadano, respuestas, cambio de estado, llamada y videollamada.
class DetalleOperadorScreen extends StatelessWidget {
  const DetalleOperadorScreen({super.key, required this.radicado});

  final String radicado;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ReportesRepository>();
    return StreamBuilder<Reporte?>(
      stream: repo.reporte(radicado),
      builder: (context, snap) {
        if (snap.hasError) {
          return Pantalla(titulo: 'Reporte', mostrar119: false, cuerpo: VistaError(alReintentar: () {}));
        }
        final r = snap.data;
        if (r == null) {
          return Pantalla(
              titulo: 'Reporte',
              mostrar119: false,
              cuerpo: snap.connectionState == ConnectionState.waiting
                  ? const Esqueleto()
                  : const VistaMensaje(
                      icono: PhosphorIconsBold.fileX, titulo: 'No existe', mensaje: 'El reporte ya no está disponible.'));
        }
        return _Contenido(reporte: r);
      },
    );
  }
}

class _Contenido extends StatefulWidget {
  const _Contenido({required this.reporte});
  final Reporte reporte;

  @override
  State<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends State<_Contenido> {
  late final TextEditingController _nota = TextEditingController(text: widget.reporte.nota ?? '');

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _cambiarEstado(EstadoReporte e) async {
    final auth = context.read<AuthService>();
    try {
      await context.read<ReportesRepository>().cambiarEstado(widget.reporte.radicado, e, auth.uid ?? 'operador');
      if (mounted) avisar(context, 'Estado: ${e.etiqueta}.');
    } catch (_) {
      if (mounted) avisar(context, 'No se pudo cambiar el estado. Revise la conexión.');
    }
  }

  Future<void> _videollamada() async {
    final r = widget.reporte;
    if (!AppConfig.agoraListo) {
      avisar(context, 'Falta configurar AGORA_APP_ID para hacer videollamadas.');
      return;
    }
    final repo = context.read<ReportesRepository>();
    final nombre = context.read<AuthService>().perfil?.nombre ?? 'Radio operador';
    if (!r.videollamada.activa) {
      await repo.iniciarVideollamada(r.radicado, nombre.isEmpty ? 'Radio operador' : nombre);
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => VideollamadaScreen(radicado: r.radicado, esOperador: true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reporte;
    final t = Theme.of(context).textTheme;
    final protocolo = context.read<Protocolo>();
    final tarjeta = protocolo.tarjeta(r.tarjetaId);
    final claves = protocolo.clavesDe(r.tarjetaId);
    final info = infoDe(r.categoria);
    final repo = context.read<ReportesRepository>();
    final llamando = r.videollamada.estado == EstadoLlamada.llamando;

    return Pantalla(
      titulo: r.radicado,
      mostrar119: false,
      cuerpo: Cuerpo(hijos: [
        Row(children: [
          PhosphorIcon(info.icono, size: 34, color: Palette.oxido),
          const SizedBox(width: Space.m),
          Expanded(child: Text(r.tarjetaNombre ?? info.etiqueta, style: t.headlineSmall)),
          InsigniaPrioridad(r.prioridad),
        ]),
        const SizedBox(height: Space.xs),
        Text('${info.etiqueta} · recibido ${hace(r.creadoEn)}', style: t.bodyMedium),
        const SizedBox(height: Space.l),

        // Acciones principales
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: Estilos.oscuro().copyWith(minimumSize: const WidgetStatePropertyAll(Size(64, Sizes.primaryButton))),
              onPressed: _videollamada,
              icon: const PhosphorIcon(PhosphorIconsBold.videoCamera),
              label: Text(r.videollamada.activa ? 'Volver a la llamada' : 'Videollamada'),
            ),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, Sizes.primaryButton)),
              onPressed: r.telefono.isEmpty ? null : () => Enlaces.llamar(r.telefono),
              icon: const PhosphorIcon(PhosphorIconsBold.phone),
              label: const Text('Llamar'),
            ),
          ),
        ]),
        if (llamando) ...[
          const SizedBox(height: Space.s),
          Row(children: [
            Expanded(child: Text('Llamando al ciudadano…', style: t.bodyMedium)),
            TextButton(onPressed: () => repo.terminarVideollamada(r.radicado), child: const Text('Cancelar llamada')),
          ]),
        ] else if (r.videollamada.estado == EstadoLlamada.rechazada)
          Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: Text('El ciudadano no pudo contestar la videollamada.', style: t.bodyMedium),
          ),
        const SeparadorManguera(),

        // Ubicacion
        const EncabezadoSeccion('Ubicación'),
        if (r.ubicacion != null) ...[
          _MapaReporte(ubicacion: r.ubicacion!),
          const SizedBox(height: Space.s),
          Text('${r.ubicacion!.lat.toStringAsFixed(6)}, ${r.ubicacion!.lng.toStringAsFixed(6)}'
              '${r.ubicacion!.precisionM != null ? ' · precisión ${r.ubicacion!.precisionM!.round()} m' : ''}',
              style: t.bodyMedium),
          const SizedBox(height: Space.s),
          FilledButton.icon(
            onPressed: () => Enlaces.mapa(r.ubicacion!.lat, r.ubicacion!.lng),
            icon: const PhosphorIcon(PhosphorIconsBold.mapTrifold),
            label: const Text('ABRIR EN GOOGLE MAPS'),
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(Space.m),
            decoration: BoxDecoration(color: Palette.rojoSuave, borderRadius: Radii.card),
            child: Text('El ciudadano no compartió el GPS. Use la referencia escrita.', style: t.bodyMedium),
          ),
        if (r.referencia != null) ...[
          const SizedBox(height: Space.s),
          Text('Referencia: ${r.referencia}', style: t.bodyLarge),
        ],
        if (r.descripcion != null) ...[
          const SizedBox(height: Space.s),
          Text('Descripción: ${r.descripcion}', style: t.bodyLarge),
        ],
        const SeparadorManguera(),

        // Estado
        const EncabezadoSeccion('Estado'),
        Wrap(spacing: Space.s, runSpacing: Space.s, children: [
          for (final e in EstadoReporte.values)
            ChoiceChip(
              label: Text(e.etiqueta),
              selected: r.estado == e,
              showCheckmark: false,
              labelStyle: t.labelLarge?.copyWith(color: r.estado == e ? Palette.ceniza : Palette.carbon),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.m),
              onSelected: r.estado == e ? null : (_) => _cambiarEstado(e),
            ),
        ]),
        const SizedBox(height: Space.m),
        Row(children: [
          Text('Prioridad', style: t.labelLarge),
          const SizedBox(width: Space.m),
          Expanded(
            child: Wrap(spacing: Space.s, children: [
              for (final p in Prioridad.values)
                ChoiceChip(
                  label: Text(p.etiqueta),
                  selected: r.prioridad == p,
                  showCheckmark: false,
                  labelStyle: t.labelMedium?.copyWith(color: r.prioridad == p ? Palette.ceniza : Palette.carbon),
                  onSelected: (_) => repo.cambiarPrioridad(r.radicado, p),
                ),
            ]),
          ),
        ]),
        const SeparadorManguera(),

        // Ciudadano
        const EncabezadoSeccion('Ciudadano'),
        _Fila('Nombre', r.nombre),
        _Fila('Teléfono', r.telefono),
        _Fila('Cuenta', r.registrado ? 'Usuario registrado' : 'Sin cuenta'),
        const SeparadorManguera(),

        // Media
        const EncabezadoSeccion('Fotos y video'),
        GaleriaMedia(items: r.media, pendientes: r.mediaPendiente),
        const SeparadorManguera(),

        // Respuestas
        const EncabezadoSeccion('Respuestas del cuestionario'),
        if (!r.cuestionarioCompleto)
          Text('El ciudadano aún no respondió el cuestionario.', style: t.bodyMedium)
        else if (r.respuestas.isEmpty)
          Text('Envió el cuestionario sin respuestas.', style: t.bodyMedium)
        else
          for (final q in claves)
            if (r.respuestas[q.clave] != null) _Fila(textoPregunta(q.texto), _legible(r.respuestas[q.clave]!)),
        const SeparadorManguera(),

        // Protocolo
        if (tarjeta != null && tarjeta.despacho.isNotEmpty) ...[
          const EncabezadoSeccion('Códigos de despacho del protocolo'),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(tarjeta.nombre, style: t.titleMedium),
              subtitle: Text('${tarjeta.despacho.length} condiciones', style: t.bodySmall),
              children: [
                for (final d in tarjeta.despacho)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 44,
                      child: Text(d.codigo ?? '—', style: t.titleLarge?.copyWith(color: Palette.oxido)),
                    ),
                    title: Text(d.descripcion, style: t.bodyMedium),
                  ),
              ],
            ),
          ),
          const SeparadorManguera(),
        ],

        // Nota e historial
        const EncabezadoSeccion('Nota del operador'),
        TextField(
          controller: _nota,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Observaciones internas'),
        ),
        const SizedBox(height: Space.s),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: () async {
              await repo.guardarNota(r.radicado, _nota.text.trim());
              if (context.mounted) avisar(context, 'Nota guardada.');
            },
            child: const Text('Guardar nota'),
          ),
        ),
        if (r.historial.isNotEmpty) ...[
          const SeparadorManguera(),
          const EncabezadoSeccion('Historial'),
          for (final h in r.historial.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Text('${diaYHora(h.en)} · ${h.estado.etiqueta}', style: t.bodyMedium),
            ),
        ],
      ]),
    );
  }

  static String _legible(String v) => switch (v) { 'si' => 'Sí', 'no' => 'No', 'nosabe' => 'No sabe', _ => v };
}

class _Fila extends StatelessWidget {
  const _Fila(this.titulo, this.valor);
  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: t.bodySmall),
        Text(valor.isEmpty ? '—' : valor, style: t.titleMedium),
      ]),
    );
  }
}

class _MapaReporte extends StatelessWidget {
  const _MapaReporte({required this.ubicacion});
  final Ubicacion ubicacion;

  @override
  Widget build(BuildContext context) {
    final pos = LatLng(ubicacion.lat, ubicacion.lng);
    return ClipRRect(
      borderRadius: Radii.card,
      child: SizedBox(
        height: 220,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: pos, zoom: 16.5),
          markers: {Marker(markerId: const MarkerId('r'), position: pos)},
          circles: {
            if ((ubicacion.precisionM ?? 0) > 0)
              Circle(
                circleId: const CircleId('p'),
                center: pos,
                radius: ubicacion.precisionM!,
                fillColor: Palette.brasa.withValues(alpha: 0.15),
                strokeColor: Palette.brasaOscura,
                strokeWidth: 1,
              ),
          },
          liteModeEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
        ),
      ),
    );
  }
}
