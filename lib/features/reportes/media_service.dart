import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';

import '../../core/config/app_config.dart';
import 'cola_offline.dart';
import 'models.dart';

/// Comprime y sube a Cloudinary con subida unsigned (upload preset), sin
/// secretos en la app. Limites del plan gratuito: 10 MB por imagen y 100 MB
/// por video; por eso se comprime antes (ver DECISIONES.md).
class MediaService {
  MediaService({http.Client? cliente}) : _http = cliente ?? http.Client();

  final http.Client _http;

  static const maxFotoBytes = 10 * 1024 * 1024;
  static const maxVideoBytes = 100 * 1024 * 1024;

  /// Copia el archivo a una carpeta propia de la app para que la cola lo
  /// conserve aunque el usuario borre la foto de la galeria o se cierre la app.
  Future<String> guardarParaCola(String origen) async {
    final dir = Directory(p.join((await getApplicationSupportDirectory()).path, 'cola'));
    await dir.create(recursive: true);
    final destino = p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}${p.extension(origen)}');
    await File(origen).copy(destino);
    return destino;
  }

  Future<File> _comprimirFoto(File f) async {
    final tmp = await getTemporaryDirectory();
    final out = p.join(tmp.path, 'c_${DateTime.now().microsecondsSinceEpoch}.jpg');
    // Lado largo 1600 px y calidad 78: legible para el operador, ~300-600 KB.
    final r = await FlutterImageCompress.compressAndGetFile(
      f.path,
      out,
      minWidth: 1600,
      minHeight: 1600,
      quality: 78,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (r == null) throw ErrorPermanente('No se pudo comprimir la foto');
    return File(r.path);
  }

  Future<File> _comprimirVideo(File f) async {
    try {
      // Calidad media: ~720p y bitrate reducido. Un video de 1 minuto pasa de
      // decenas de MB a unos pocos.
      final r = await VideoCompress.compressVideo(
        f.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      final salida = r?.file;
      if (salida != null && await salida.exists() && await salida.length() < await f.length()) return salida;
    } catch (_) {
      // Si el compresor falla se sube el original mientras no pase del limite.
    }
    return f;
  }

  /// Comprime y sube. Lanza [ErrorReintentable] si es un problema de red.
  Future<MediaItem> subir(ArchivoPendiente a) async {
    if (!AppConfig.cloudinaryListo) {
      throw ErrorReintentable('Cloudinary sin configurar');
    }
    final original = File(a.ruta);
    if (!await original.exists()) throw ErrorPermanente('El archivo ya no existe');

    final esFoto = a.tipo == TipoMedia.foto;
    final f = esFoto ? await _comprimirFoto(original) : await _comprimirVideo(original);
    final bytes = await f.length();
    if (bytes > (esFoto ? maxFotoBytes : maxVideoBytes)) {
      throw ErrorPermanente('El archivo supera el limite de Cloudinary');
    }

    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloud}/${esFoto ? 'image' : 'video'}/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryPreset
      ..fields['folder'] = 'reportes'
      ..files.add(await http.MultipartFile.fromPath('file', f.path));

    try {
      final resp = await http.Response.fromStream(await _http.send(req).timeout(const Duration(minutes: 3)));
      if (resp.statusCode == 200) {
        final j = json.decode(resp.body) as Map<String, dynamic>;
        _limpiar(f, original);
        return MediaItem(
          url: j['secure_url'] as String,
          tipo: a.tipo,
          publicId: j['public_id'] as String?,
          bytes: (j['bytes'] as num?)?.toInt(),
        );
      }
      // 4xx: configuracion o archivo invalido; 5xx y 429: reintentar.
      if (resp.statusCode >= 500 || resp.statusCode == 429) {
        throw ErrorReintentable('Cloudinary ${resp.statusCode}');
      }
      throw ErrorPermanente('Cloudinary ${resp.statusCode}: ${resp.body}');
    } on SocketException {
      throw ErrorReintentable('Sin conexion');
    } on http.ClientException {
      throw ErrorReintentable('Sin conexion');
    } on Exception catch (e) {
      if (e is ErrorPermanente || e is ErrorReintentable) rethrow;
      throw ErrorReintentable('$e');
    }
  }

  void _limpiar(File comprimido, File original) {
    try {
      if (comprimido.path != original.path) comprimido.deleteSync();
      if (original.path.contains('${p.separator}cola${p.separator}')) original.deleteSync();
    } catch (_) {}
  }
}
