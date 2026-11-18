import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/estilos.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/servicios_dispositivo.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/permisos.dart';
import '../auth/auth_service.dart';
import '../protocolo/protocolo.dart';
import '../reportes/envio_controller.dart';
import '../reportes/models.dart';
import 'confirmacion_screen.dart';

/// Nombre que lleva el reporte rapido cuando todavia no se sabe quien lo envia.
const nombreSinIdentificar = 'Sin identificar';

/// Reporte de un solo toque: pide la foto, toma la ubicacion del GPS y envia.
/// El tipo, la descripcion y los datos de contacto se completan despues
/// (ver `DetallesReporteScreen`). La ubicacion se busca mientras se abre la
/// camara para no hacer esperar a la persona.
Future<void> iniciarReporteRapido(BuildContext context) async {
  final envio = context.read<EnvioController>();
  final geo = context.read<UbicacionService>();
  HapticFeedback.mediumImpact();

  final espera = envio.esperaPorLimite();
  if (espera != null) {
    await mostrarLimiteExcedido(context, espera);
    return;
  }

  // 1. Ubicacion. Si la persona no la da, el reporte sale igual y despues se
  // le pide una direccion.
  await pedirPermisoConExplicacion(
    context,
    permiso: Permission.locationWhenInUse,
    titulo: 'Compartir su ubicación',
    motivo: 'Los Bomberos necesitan saber dónde está la emergencia. La aplicación envía las coordenadas '
        'del GPS junto con la foto, para que no tenga que explicar la dirección.',
    icono: PhosphorIconsBold.mapPin,
    siNiega: 'Sin la ubicación tendrá que escribir la dirección después de enviar la foto.',
  );
  if (!context.mounted) return;
  final ubicacion = geo.obtener(pedirPermiso: false);

  // 2. Camara.
  final okCamara = await pedirPermisoConExplicacion(
    context,
    permiso: Permission.camera,
    titulo: 'Usar la cámara',
    motivo: 'Para tomar la foto de la emergencia y enviarla a los Bomberos.',
    icono: PhosphorIconsBold.camera,
    siNiega: 'Puede reportar con el formulario, sin foto, o llamar al 119.',
  );
  if (!context.mounted) return;
  if (!okCamara) {
    avisar(context, 'Sin la cámara no se puede enviar la foto. Use "Reportar con más detalle" o llame al 119.');
    return;
  }

  XFile? foto;
  try {
    foto = await ImagePicker().pickImage(source: ImageSource.camera);
  } on PlatformException {
    if (context.mounted) avisar(context, 'No se pudo abrir la cámara. Revise los permisos del teléfono.');
    return;
  }
  if (foto == null || !context.mounted) return;

  // 3. Envio. Lo que no haya salido queda en la cola y se reintenta solo.
  await _enviarFoto(context, foto.path, ubicacion);
}

/// Si Android cerro la app mientras estaba abierta la camara (poca memoria),
/// la foto tomada queda guardada por el sistema. Al volver se recupera y se
/// envia como reporte rapido, para no perderla justo en una emergencia.
Future<void> recuperarFotoPerdida(BuildContext context) async {
  XFile? foto;
  try {
    final r = await ImagePicker().retrieveLostData();
    if (r.isEmpty || r.file == null || r.type == RetrieveType.video) return;
    foto = r.file;
  } catch (_) {
    return;
  }
  if (foto == null || !context.mounted) return;
  avisar(context, 'Recuperamos la foto que estaba tomando. La estamos enviando.');
  final ubicacion = context.read<UbicacionService>().obtener(pedirPermiso: false);
  await _enviarFoto(context, foto.path, ubicacion);
}

Future<void> _enviarFoto(BuildContext context, String ruta, Future<ResultadoUbicacion> ubicacion) async {
  final envio = context.read<EnvioController>();
  final protocolo = context.read<Protocolo>();
  final auth = context.read<AuthService>();
  final disp = context.read<DispositivoService>();
  final navegador = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(canPop: false, child: _EnviandoDialogo()),
  );
  Reporte? reporte;
  try {
    final u = await ubicacion.timeout(
      const Duration(seconds: 12),
      onTimeout: () => const UbicacionFallida(FalloUbicacion.sinSenal),
    );
    final p = auth.perfil;
    final deCuenta = auth.registrado && p != null && p.nombre.isNotEmpty;
    final nombre = deCuenta ? p.nombre : disp.nombreGuardado;
    final telefono = deCuenta && p.telefono.isNotEmpty ? p.telefono : disp.telefonoGuardado;
    reporte = await envio.enviar(BorradorReporte(
      categoria: protocolo.categoria('900')!,
      nombre: nombre.isEmpty ? nombreSinIdentificar : nombre,
      telefono: telefono,
      ubicacion: u is UbicacionObtenida ? u.ubicacion : null,
      archivos: [ArchivoElegido(ruta, TipoMedia.foto)],
    ));
  } on LimiteExcedido catch (e) {
    navegador.pop();
    if (context.mounted) await mostrarLimiteExcedido(context, e.espera);
    return;
  } catch (_) {
    navegador.pop();
    if (context.mounted) avisar(context, 'No se pudo guardar el reporte. Intente de nuevo o llame al 119.');
    return;
  }
  navegador.pop();
  if (!context.mounted) return;
  HapticFeedback.mediumImpact();
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ConfirmacionScreen(radicado: reporte!.radicado, reporteInicial: reporte),
  ));
}

Future<void> mostrarLimiteExcedido(BuildContext context, Duration espera) {
  final min = (espera.inSeconds / 60).ceil().clamp(1, 60);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ya envió varios reportes'),
      content: Text('Desde este teléfono se enviaron 3 reportes en los últimos 10 minutos. '
          'Podrá enviar otro en $min ${min == 1 ? 'minuto' : 'minutos'}.\n\n'
          'Si es una emergencia nueva y urgente, llame al 119.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
        FilledButton(
          style: Estilos.emergencia(alto: Sizes.touch),
          onPressed: () => Enlaces.llamar('119'),
          child: const Text('LLAMAR 119'),
        ),
      ],
    ),
  );
}

class _EnviandoDialogo extends StatelessWidget {
  const _EnviandoDialogo();

  @override
  Widget build(BuildContext context) => AlertDialog(
        content: Row(children: [
          const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 4)),
          const SizedBox(width: Space.l),
          Expanded(child: Text('Enviando su reporte…', style: Theme.of(context).textTheme.titleMedium)),
        ]),
      );
}
