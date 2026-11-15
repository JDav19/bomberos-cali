import 'package:bomberos_cali/core/icons/phosphor.dart';

/// Presentacion de cada categoria del protocolo en la interfaz. Los nombres
/// formales vienen del protocolo; aqui solo se agrega una etiqueta corta, una
/// ayuda con los nombres de sus tarjetas guia y un icono.
class InfoCategoria {
  const InfoCategoria(this.etiqueta, this.ayuda, this.icono);
  final String etiqueta;
  final String ayuda;
  final PhosphorIconData icono;
}

const infoCategorias = <String, InfoCategoria>{
  '100': InfoCategoria('Incendio', 'Edificio, vehículo, monte, basuras', PhosphorIconsBold.fire),
  '200': InfoCategoria('Explosión', 'Explosión o ruptura sin incendio', PhosphorIconsBold.warningOctagon),
  '300': InfoCategoria('Emergencia médica o rescate', 'Persona herida o enferma, accidente, rescate', PhosphorIconsBold.firstAid),
  '400': InfoCategoria('Condición peligrosa', 'Fuga de gas, línea eléctrica caída, derrame', PhosphorIconsBold.warningDiamond),
  '500': InfoCategoria('Llamada de servicio', 'Solicitud de servicio', PhosphorIconsBold.lifebuoy),
  '800': InfoCategoria('Clima severo o desastre', 'Clima severo y desastres naturales', PhosphorIconsBold.cloudLightning),
  '900': InfoCategoria('Otro incidente', 'Incidente especial, no clasificado', PhosphorIconsBold.shield),
};

InfoCategoria infoDe(String codigo) => infoCategorias[codigo] ?? infoCategorias['900']!;

/// Icono de una tarjeta segun el grupo del protocolo al que pertenece.
PhosphorIconData iconoTarjeta(String categoria) => infoDe(categoria).icono;
