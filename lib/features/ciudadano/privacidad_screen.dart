import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/comunes.dart';

/// Aviso sobre los datos que recoge la aplicacion. Describe lo que la app hace
/// de verdad; no promete nada que el codigo no haga.
class PrivacidadScreen extends StatelessWidget {
  const PrivacidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget bloque(String titulo, String texto) => Padding(
          padding: const EdgeInsets.only(bottom: Space.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            EncabezadoSeccion(titulo),
            Text(texto, style: t.bodyLarge),
          ]),
        );

    return Pantalla(
      titulo: 'Sus datos',
      cuerpo: Cuerpo(hijos: [
        bloque(
          'Qué se recoge',
          'Cuando envía un reporte: su ubicación del GPS, las fotos y videos que usted tome o elija, su nombre y '
              'su teléfono. Si crea una cuenta, también su correo. Las respuestas del cuestionario y los detalles '
              'que escriba se guardan en el mismo reporte.',
        ),
        bloque(
          'Para qué se usa',
          'Solo para atender la emergencia: los radio operadores de los Bomberos ven el reporte, la ubicación en '
              'el mapa y las fotos, y pueden llamarlo o hacerle una videollamada. No se usa para publicidad ni se '
              'vende.',
        ),
        bloque(
          'Dónde se guardan',
          'Los reportes, en Cloud Firestore (Google). Las fotos y videos, en Cloudinary. Esos servicios están fuera '
              'de Colombia. En el teléfono queda una copia temporal de lo que aún no se ha enviado.',
        ),
        bloque(
          'Permisos',
          'La aplicación pide la ubicación, la cámara, el micrófono y las notificaciones solo cuando los '
              'necesita, y le explica para qué. Puede negarlos: podrá reportar escribiendo la dirección y eligiendo '
              'fotos de la galería.',
        ),
        bloque(
          'Sus derechos',
          'Usted puede conocer, actualizar o pedir que se borre la información que dio, según la Ley 1581 de '
              '2012. Para hacerlo, comuníquese con los Bomberos Voluntarios de Cali.',
        ),
        Container(
          padding: const EdgeInsets.all(Space.m),
          decoration: BoxDecoration(color: Palette.ambarSuave, borderRadius: Radii.card),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PhosphorIcon(PhosphorIconsBold.eye, color: Palette.oxido),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(
                'Esta versión es un proyecto académico de la Universidad Santiago de Cali. Los reportes no '
                'llegan a una central real de los Bomberos. En una emergencia, llame al 119.',
                style: t.bodyMedium,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
