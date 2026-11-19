import 'dart:convert';
import 'dart:io';

import 'package:bomberos_cali/features/videollamada/token_agora.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el token tiene version 007 y contiene app, canal y uid', () {
    final t = generarTokenAgora(
      appId: '0123456789abcdef0123456789abcdef',
      certificado: 'fedcba9876543210fedcba9876543210',
      canal: 'BC-261118-ABCDEFG',
      uid: 1001,
      ahora: DateTime.utc(2026, 11, 19),
      sal: 12345,
    );
    expect(t.startsWith('007'), isTrue);
    final bytes = zlib.decode(base64.decode(t.substring(3)));
    final txt = latin1.decode(bytes);
    expect(txt, contains('0123456789abcdef0123456789abcdef'));
    expect(txt, contains('BC-261118-ABCDEFG'));
    expect(txt, contains('1001'));
  });
}
