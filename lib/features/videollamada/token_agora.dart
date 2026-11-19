import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Genera un token RTC de Agora (AccessToken2, version "007") en el telefono.
///
/// Los proyectos nuevos de Agora nacen en modo seguro y exigen un token por
/// canal. Lo correcto es emitirlo desde un servidor; como el proyecto no tiene
/// servidor (ver DECISIONES.md, limitaciones), se firma aqui con el certificado
/// del proyecto, que viaja en la configuracion de compilacion.
String generarTokenAgora({
  required String appId,
  required String certificado,
  required String canal,
  required int uid,
  Duration vigencia = const Duration(hours: 2),
  DateTime? ahora,
  int? sal,
}) {
  final emision = (ahora ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  final salt = sal ?? Random.secure().nextInt(0xFFFFFFFF) + 1;
  final expira = vigencia.inSeconds;

  final firma1 = Hmac(sha256, _u32(emision)).convert(utf8.encode(certificado)).bytes;
  final clave = Hmac(sha256, _u32(salt)).convert(firma1).bytes;

  // Servicio RTC (tipo 1) con permiso de entrar y publicar audio, video y datos.
  final servicio = BytesBuilder()
    ..add(_u16(1))
    ..add(_u16(4))
    ..add(_privilegio(1, expira))
    ..add(_privilegio(2, expira))
    ..add(_privilegio(3, expira))
    ..add(_privilegio(4, expira))
    ..add(_texto(canal))
    ..add(_texto('$uid'));

  final info = BytesBuilder()
    ..add(_texto(appId))
    ..add(_u32(emision))
    ..add(_u32(expira))
    ..add(_u32(salt))
    ..add(_u16(1))
    ..add(servicio.toBytes());
  final infoBytes = info.toBytes();

  final firma = Hmac(sha256, clave).convert(infoBytes).bytes;
  final contenido = BytesBuilder()
    ..add(_texto2(firma))
    ..add(infoBytes);
  return '007${base64.encode(zlib.encode(contenido.toBytes()))}';
}

Uint8List _u16(int v) => (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List();
Uint8List _u32(int v) => (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();
Uint8List _privilegio(int clave, int valor) => Uint8List.fromList([..._u16(clave), ..._u32(valor)]);
Uint8List _texto(String s) => _texto2(utf8.encode(s));
Uint8List _texto2(List<int> b) => Uint8List.fromList([..._u16(b.length), ...b]);
