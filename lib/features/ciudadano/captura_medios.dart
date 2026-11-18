import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';

import '../../core/widgets/comunes.dart';
import '../../core/widgets/permisos.dart';
import '../reportes/envio_controller.dart';
import '../reportes/models.dart';
import 'hoja_recomendaciones.dart';

const _extVideo = {'.mp4', '.mov', '.3gp', '.mkv', '.webm', '.avi', '.m4v'};

bool _esVideo(String ruta) {
  final i = ruta.lastIndexOf('.');
  return i >= 0 && _extVideo.contains(ruta.substring(i).toLowerCase());
}

/// Muestra las recomendaciones, pide el permiso en el momento y devuelve los
/// archivos elegidos (camara o galeria). Lista vacia si la persona cancela.
Future<List<ArchivoElegido>> capturarMedios(BuildContext context, {required int restantes}) async {
  if (restantes <= 0) {
    avisar(context, 'Ya llegó al máximo de archivos para este reporte.');
    return const [];
  }
  final fuente = await mostrarHojaRecomendaciones(context);
  if (fuente == null || !context.mounted) return const [];
  final picker = ImagePicker();
  try {
    switch (fuente) {
      case FuenteMedia.foto:
        if (!await _permisoCamara(context)) return const [];
        final x = await picker.pickImage(source: ImageSource.camera);
        return [if (x != null) ArchivoElegido(x.path, TipoMedia.foto)];
      case FuenteMedia.video:
        if (!await _permisoCamara(context)) return const [];
        final x = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60));
        return [if (x != null) ArchivoElegido(x.path, TipoMedia.video)];
      case FuenteMedia.galeria:
        final xs = restantes >= 2 ? await picker.pickMultipleMedia(limit: restantes) : [?await picker.pickMedia()];
        return [for (final x in xs) ArchivoElegido(x.path, _esVideo(x.path) ? TipoMedia.video : TipoMedia.foto)];
    }
  } on PlatformException {
    if (context.mounted) avisar(context, 'No se pudo abrir la cámara o la galería. Revise los permisos del teléfono.');
    return const [];
  }
}

Future<bool> _permisoCamara(BuildContext context) => pedirPermisoConExplicacion(
      context,
      permiso: Permission.camera,
      titulo: 'Usar la cámara',
      motivo: 'Para tomar fotos o grabar un video de la emergencia y enviarlos a los Bomberos.',
      icono: PhosphorIconsBold.camera,
      siNiega: 'Puede elegir fotos de la galería sin dar este permiso.',
    );
