import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/estilos.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/permisos.dart';
import '../reportes/models.dart';
import '../reportes/reportes_repository.dart';

/// Videollamada con Agora. El operador la inicia desde el detalle del reporte
/// y el ciudadano la contesta. Los dos entran al mismo canal (el radicado).
/// La "senalizacion" (llamando, aceptada, finalizada) viaja por el documento
/// del reporte en Firestore, sin servidor propio.
class VideollamadaScreen extends StatefulWidget {
  const VideollamadaScreen({super.key, required this.radicado, required this.esOperador});

  final String radicado;
  final bool esOperador;

  @override
  State<VideollamadaScreen> createState() => _VideollamadaScreenState();
}

class _VideollamadaScreenState extends State<VideollamadaScreen> {
  RtcEngine? _engine;
  int? _remoto;
  bool _unido = false;
  bool _micApagado = false;
  bool _camaraApagada = false;
  String? _error;
  bool _cerrando = false;
  StreamSubscription<Reporte?>? _sub;

  int get _uidLocal => widget.esOperador ? 1001 : 1002;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciar());
  }

  Future<void> _iniciar() async {
    if (!AppConfig.agoraListo) {
      setState(() => _error = 'La videollamada no está configurada (falta AGORA_APP_ID).');
      return;
    }
    final cam = await pedirPermisoConExplicacion(
      context,
      permiso: Permission.camera,
      titulo: 'Usar la cámara',
      motivo: 'Para que los Bomberos vean en tiempo real lo que ocurre en el lugar.',
      icono: PhosphorIconsBold.videoCamera,
    );
    if (!mounted) return;
    final mic = await pedirPermisoConExplicacion(
      context,
      permiso: Permission.microphone,
      titulo: 'Usar el micrófono',
      motivo: 'Para que pueda hablar con el radio operador durante la videollamada.',
      icono: PhosphorIconsBold.microphone,
    );
    if (!mounted) return;
    if (!cam || !mic) {
      setState(() => _error = 'Sin permiso de cámara y micrófono no se puede hacer la videollamada.');
      return;
    }

    try {
      final e = createAgoraRtcEngine();
      await e.initialize(const RtcEngineContext(
        appId: AppConfig.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      e.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) {
          if (mounted) setState(() => _unido = true);
        },
        onUserJoined: (conn, uid, elapsed) {
          if (mounted) setState(() => _remoto = uid);
        },
        onUserOffline: (conn, uid, reason) {
          if (mounted) {
            setState(() => _remoto = null);
            _terminar(avisarOtro: false);
          }
        },
        onError: (err, msg) {
          if (mounted) setState(() => _error = 'Error de la videollamada ($msg).');
        },
      ));
      await e.enableVideo();
      await e.enableAudio();
      await e.startPreview();
      await e.joinChannel(
        token: AppConfig.agoraTempToken,
        channelId: widget.radicado,
        uid: _uidLocal,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      _engine = e;
      if (!mounted) return;
      // Si el otro lado corta (finalizada o rechazada), se cierra solo.
      _sub = context.read<ReportesRepository>().reporte(widget.radicado).listen((r) {
        final est = r?.videollamada.estado;
        if (est == EstadoLlamada.finalizada || est == EstadoLlamada.rechazada) {
          _terminar(avisarOtro: false);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo iniciar la videollamada. Revise su conexión.');
    }
  }

  Future<void> _terminar({bool avisarOtro = true}) async {
    if (_cerrando) return;
    _cerrando = true;
    await _sub?.cancel();
    if (avisarOtro && mounted) {
      final repo = context.read<ReportesRepository>();
      try {
        await repo.terminarVideollamada(widget.radicado).timeout(const Duration(seconds: 4));
      } catch (_) {}
    }
    final e = _engine;
    _engine = null;
    if (e != null) {
      try {
        await e.leaveChannel();
        await e.release();
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    final e = _engine;
    _engine = null;
    if (e != null) {
      e.leaveChannel().then((_) => e.release()).catchError((Object _) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = _engine;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _terminar();
      },
      child: Scaffold(
        backgroundColor: Palette.carbon,
        body: SafeArea(
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.xl),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const PhosphorIcon(PhosphorIconsBold.videoCameraSlash, color: Palette.ceniza, size: 56),
                      const SizedBox(height: Space.l),
                      Text(_error!, style: t.titleMedium?.copyWith(color: Palette.ceniza), textAlign: TextAlign.center),
                      const SizedBox(height: Space.xl),
                      FilledButton(onPressed: () => _terminar(), child: const Text('CERRAR')),
                    ]),
                  ),
                )
              : Stack(children: [
                  Positioned.fill(
                    child: (e != null && _remoto != null)
                        ? AgoraVideoView(
                            controller: VideoViewController.remote(
                              rtcEngine: e,
                              canvas: VideoCanvas(uid: _remoto),
                              connection: RtcConnection(channelId: widget.radicado),
                            ),
                          )
                        : Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Palette.brasa)),
                              const SizedBox(height: Space.l),
                              Text(
                                widget.esOperador
                                    ? (_unido ? 'Esperando que el ciudadano conteste…' : 'Conectando…')
                                    : 'Conectando con los Bomberos…',
                                style: t.titleMedium?.copyWith(color: Palette.ceniza),
                              ),
                            ]),
                          ),
                  ),
                  if (e != null && _unido && !_camaraApagada)
                    Positioned(
                      right: Space.l,
                      top: Space.l,
                      width: 110,
                      height: 150,
                      child: ClipRRect(
                        borderRadius: Radii.card,
                        child: AgoraVideoView(
                          controller: VideoViewController(rtcEngine: e, canvas: const VideoCanvas(uid: 0)),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: Space.xl,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _Control(
                        icono: _micApagado ? PhosphorIconsBold.microphoneSlash : PhosphorIconsBold.microphone,
                        etiqueta: _micApagado ? 'Activar micrófono' : 'Silenciar micrófono',
                        activo: _micApagado,
                        alTocar: e == null
                            ? null
                            : () async {
                                setState(() => _micApagado = !_micApagado);
                                await e.muteLocalAudioStream(_micApagado);
                              },
                      ),
                      const SizedBox(width: Space.l),
                      FilledButton(
                        style: Estilos.emergencia().copyWith(
                          minimumSize: const WidgetStatePropertyAll(Size(72, 72)),
                          shape: const WidgetStatePropertyAll(CircleBorder()),
                          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                        ),
                        onPressed: () => _terminar(),
                        child: Semantics(
                          label: 'Terminar videollamada',
                          child: const PhosphorIcon(PhosphorIconsFill.phoneDisconnect, size: 32),
                        ),
                      ),
                      const SizedBox(width: Space.l),
                      _Control(
                        icono: _camaraApagada ? PhosphorIconsBold.videoCameraSlash : PhosphorIconsBold.videoCamera,
                        etiqueta: _camaraApagada ? 'Activar cámara' : 'Apagar cámara',
                        activo: _camaraApagada,
                        alTocar: e == null
                            ? null
                            : () async {
                                setState(() => _camaraApagada = !_camaraApagada);
                                await e.muteLocalVideoStream(_camaraApagada);
                              },
                      ),
                    ]),
                  ),
                  if (e != null)
                    Positioned(
                      left: Space.l,
                      top: Space.l,
                      child: IconButton.filledTonal(
                        tooltip: 'Cambiar de cámara',
                        onPressed: () => e.switchCamera(),
                        icon: const PhosphorIcon(PhosphorIconsBold.cameraRotate),
                      ),
                    ),
                ]),
        ),
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({required this.icono, required this.etiqueta, required this.activo, required this.alTocar});
  final PhosphorIconData icono;
  final String etiqueta;
  final bool activo;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: etiqueta,
        child: Material(
          color: activo ? Palette.ceniza : Palette.carbon,
          shape: CircleBorder(side: BorderSide(color: Palette.ceniza.withValues(alpha: 0.7), width: 1.5)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: alTocar,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Center(child: PhosphorIcon(icono, color: activo ? Palette.carbon : Palette.ceniza, size: 28)),
            ),
          ),
        ),
      );
}
