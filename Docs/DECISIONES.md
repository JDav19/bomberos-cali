# Decisiones técnicas

Cada decisión indica qué se consideró, qué se eligió y por qué. Lo que no pude verificar está marcado como **sin verificar**.

## 1. Base de datos en la nube: Cloud Firestore + Firebase Auth

| Opción | Pros | Contras en este proyecto |
|---|---|---|
| **Cloud Firestore (elegida)** | Escuchas en tiempo real incluidas (la bandeja del operador y el estado del ciudadano se actualizan solos), caché y escritura sin conexión en el SDK, reglas de seguridad por documento, plan gratuito sin tarjeta | Consultas limitadas (sin agregaciones complejas); el límite diario de lecturas y escrituras del plan gratuito |
| Realtime Database | También en tiempo real | Modelo de árbol único, sin consultas por campo ni reglas tan finas; el listener del operador descargaría todo el árbol |
| API propia (Node + base de datos, como en las clases de Railway) | Control total | Hay que construir y mantener autenticación, tiempo real y servidor; no hay tiempo antes del 19 de noviembre |
| Supabase | Postgres y tiempo real | Segunda plataforma que aprender, sin SDK Flutter tan integrado con reglas por usuario como Firestore |

**Sin Firebase Storage ni Cloud Functions**, como pide el encargo: exigen el plan Blaze. Consecuencias que se aceptan y se resuelven así:
- Archivos: Cloudinary (sección 2).
- Avisos al ciudadano: listeners de Firestore más notificaciones locales (sección 7).
- Límites de envío: del lado del cliente (sección 4).

**Un documento por reporte**, con el radicado como id: `reportes/{radicado}`. Respuestas, archivos y estado viven en el mismo documento. Se evita una subcolección porque el operador lee todo el reporte de una sola vez y las reglas se escriben sobre un solo documento.

**Cuota del plan gratuito (sin verificar en la consola, de memoria del plan Spark):** unas 50.000 lecturas y 20.000 escrituras por día. Un reporte con 3 fotos gasta ~5 escrituras (crear, 3 archivos, cambio de estado), así que el techo ronda los 4.000 reportes diarios. Para la demo sobra. Para una emergencia masiva real se necesita el plan Blaze; está documentado como propuesta (sección 5).

**Rol en Firestore.** `usuarios/{uid}.rol` vale `ciudadano` u `operador`. Las reglas (`firestore.rules`) lo consultan con `get()`. Quien no tiene documento de usuario es ciudadano. Todo ciudadano nuevo recibe una sesión **anónima** de Firebase para poder reportar sin cuenta; al registrarse, la cuenta se **enlaza** a esa misma identidad (`linkWithCredential`) y conserva sus reportes anteriores.

**Riesgo conocido de la demo.** La regla `esCuentaOperadorDemo` deja que `operador.demo@bomberoscali.app` se cree con rol operador sin pasar por la consola. Cualquiera que registre ese correo antes que nosotros tendría ese rol. Está marcada para borrarla antes de un uso real.

## 2. Fotos y videos: Cloudinary con subida unsigned

| Opción | Evaluación |
|---|---|
| **Cloudinary, upload preset *unsigned* (elegida)** | Lo sugiere el enunciado. Subida directa desde el teléfono con un POST; sin servidor; transformaciones por URL (miniaturas de fotos y fotograma de video con solo cambiar la URL) |
| Firebase Storage | Requiere plan Blaze |
| Guardar en Base64 dentro de Firestore | Documentos de 1 MiB máximo y cobra lecturas por cada byte; inviable para video |
| S3 u otro bucket | Necesita URLs firmadas generadas por un servidor |

**Compresión antes de subir** (`media_service.dart`):
- Foto: lado largo de 1.600 px, JPEG calidad 78, sin EXIF (también quita la ubicación incrustada). Una foto de 8 MB queda en unos 300 a 600 KB.
- Video: calidad media con `video_compress` (transcodificación en el teléfono). Máximo 1 minuto al grabar. Si el compresor falla se sube el original solo si no pasa del límite del plan.
- Límites del plan gratuito de Cloudinary que la app respeta: 10 MB por imagen y 100 MB por video.

**Primero el reporte, después los archivos.** El reporte (texto y coordenadas) se escribe en Firestore antes de subir nada. El documento lleva `mediaPendiente` para que el operador vea "faltan 2 archivos". Si la subida falla, el reporte ya llegó y los archivos se reintentan.

**Riesgo de la subida unsigned.** Quien conozca el nombre del preset puede subir archivos a la cuenta. Mitigación: el preset restringe carpeta y formatos permitidos. Un preset firmado exigiría un servidor para firmar, que no tenemos.

**Recomendaciones previas a la captura.** Una hoja flotante aparece siempre antes de abrir la cámara: plano general primero, luego detalles, distancia segura y no arriesgarse. Son las que pide el enunciado; no son instrucciones del protocolo de despacho.

## 3. Videollamada: Agora

El operador inicia y el ciudadano contesta. Comparación con lo que pude verificar el 15 de noviembre de 2026:

| Opción | Hallazgos | Veredicto |
|---|---|---|
| **Agora (elegida)** | Documentación oficial: 10.000 minutos gratis cada mes. SDK Flutter oficial (`agora_rtc_engine`). Infraestructura propia: funciona en datos móviles sin montar TURN | Cumple |
| Jitsi (`meet.jit.si`) | La publicación oficial de Jitsi dice que ya no se permite **incrustar** `meet.jit.si`; para incrustar hay que usar JaaS (8x8) o un servidor propio. Dos fuentes difieren sobre la cuota gratuita de JaaS (minutos ilimitados hasta 25 endpoints, frente a 25 usuarios activos al mes): **sin verificar** | Descartada: la ruta gratuita para incrustar no es clara |
| ZEGOCLOUD | 10.000 minutos de prueba al registrarse, luego US$ 3,99 por 1.000 minutos-participante. Dos páginas de su documentación se contradicen sobre si cobran por usuarios o por flujos: **sin verificar**. La UI prefabricada de llamadas usa su propio servicio de mensajería para invitar | Funcional, pero con más piezas de pago potencial y menos transparente |
| WebRTC propio (`flutter_webrtc`) + señalización en Firestore | Gratis y sin proveedor | Sin servidor TURN, las redes móviles con NAT simétrico no conectan; montar y probar un TURN no cabe antes de la sustentación |

**Cómo funciona** (`features/videollamada/`). La señalización viaja por el mismo documento del reporte, sin servidor:
1. El operador toca "Videollamada": se escribe `videollamada = {estado: "llamando", canal: <radicado>}` y entra al canal de Agora.
2. El listener del ciudadano detecta `llamando`, muestra la pantalla de llamada entrante y envía una notificación local.
3. Si contesta, escribe `aceptada` y entra al mismo canal. Si no puede, escribe `rechazada`.
4. Al colgar cualquiera de los dos se escribe `finalizada` y el otro lado cierra solo.

Los permisos de cámara y micrófono se piden en ese momento, con una explicación previa.

**Límites que hay que conocer.** (a) La llamada entrante llega como notificación local, así que necesita que el proceso de la app siga vivo; si el sistema lo cerró no suena (FCM lo resolvería, pero enviar FCM sin Cloud Functions obliga a guardar una clave de servidor en la app). (b) Con "solo App ID" cualquiera con el App ID puede entrar a un canal; con certificado habría que generar tokens en un servidor. Es aceptable en una demo y se anota como propuesta de producción. (c) Que Agora permita proyectos sin certificado: **sin verificar**, lo confirma quien cree el proyecto (ver `SETUP.md`).

## 4. Emergencias de gran magnitud con envíos masivos

El problema: en un incendio grande o un accidente masivo llegan cientos de reportes casi iguales en pocos minutos, desde una zona con la red congestionada, y el operador no puede abrir uno por uno.

### Implementado

| Medida | Cómo | Por qué ese valor |
|---|---|---|
| **Cola offline con reintentos** (`cola_offline.dart`) | El reporte se guarda en un archivo del teléfono antes de intentar enviarlo y se reenvía al volver la red, al abrir la app y por temporizador. Retroceso exponencial: 5 s, 10 s, 20 s… con tope de 5 min | El retroceso evita que miles de teléfonos reintenten a la vez en el mismo segundo. Un reporte nunca se descarta; un archivo se descarta tras 8 intentos |
| **Reporte primero, archivos después** | Texto y coordenadas salen antes que cualquier foto o video | Un reporte de 2 KB llega aunque la subida de 30 MB no |
| **Compresión** | Fotos a ~400 KB y video a calidad media | Menos datos por reporte: en una red saturada es la diferencia entre llegar o no |
| **Radicado generado en el teléfono** | `BC-AAMMDD-XXXXXXX`, 7 caracteres de un alfabeto de 31 sin letras confusas | Se entrega al ciudadano aunque no haya red. Con 7 caracteres, 5.000 reportes en un día tienen ~0,05 % de probabilidad de repetir un radicado; con 5 serían ~35 % (la prueba lo mostró) |
| **Agrupación de reportes cercanos** (`agrupacion.dart`) | Dos reportes activos quedan en el mismo grupo si están a **150 m o menos** y se crearon con **15 min o menos** de diferencia; la relación es transitiva. Se muestran como "Posible mismo incidente" con un círculo en el mapa | 150 m: una cuadra y media. Cubre el error del GPS en calle con edificios (10 a 50 m) y que cada testigo esté en un punto distinto de la escena. 15 min: ventana en la que una escena genera casi todas sus llamadas. Más tiempo juntaría incidentes distintos en zonas de alto tránsito. Usa una malla por celdas, así 3.000 reportes se agrupan en milisegundos (hay prueba) |
| **Prioridad automática** (`prioridad.dart`) | Parte de la tarjeta (p. ej. ataque cardíaco, edificio alto: crítica) y las respuestas clave solo pueden subirla: no respira o está inconsciente → crítica; atrapados, 3 o más heridos, sangrado → sube un nivel | **Es criterio de la app, no del protocolo**: el protocolo no trae niveles en su texto y los colores de sus cajas no son consistentes. Los Bomberos deben validar la tabla. El operador siempre puede cambiarla |
| **Límite de envíos** (`limite_reportes.dart`) | 3 reportes cada 10 minutos por teléfono. Al alcanzarlo, la app explica cuánto falta y ofrece el 119 | Una persona real rara vez reporta más de tres emergencias distintas en 10 minutos; un toque repetido o un script sí. Nunca deja a alguien sin salida |
| **Orden de la bandeja** | Prioridad y luego el que más lleva esperando | Evita que un reporte crítico se pierda entre los nuevos |
| **Bandeja acotada** | Los 400 reportes más recientes | Una consulta de tamaño fijo mantiene el costo y el tiempo de carga |

**Límite honesto del tope por teléfono.** Es del cliente. Alguien con conocimientos puede saltarlo. Forzarlo en el servidor exige Cloud Functions o App Check con verificación, que no están en el plan gratuito. Las reglas de Firestore sí impiden que un ciudadano cree reportes a nombre de otro o que cambie estados.

### Propuestas que no alcancé a implementar
1. **Alerta a ciudadanos de una zona** ("hay un incendio en su barrio, evacúe por el norte"): requiere conocer la zona de cada teléfono (guardarla al abrir la app) y enviar FCM por tema o por celda geográfica. Necesita Cloud Functions.
2. **"Ya hay reportes aquí"**: antes de enviar, consultar si hay reportes activos a menos de 150 m y proponer "agregar mis fotos al reporte existente" en vez de crear uno nuevo. Reduce el volumen en el origen.
3. **Modo emergencia masiva** activado por el operador: acorta el formulario (solo tipo y ubicación) y omite el cuestionario y las fotos.
4. **Asignación entre varios operadores**: reclamar un reporte (`operadorUid`) para que dos operadores no lo atiendan a la vez, con un bloqueo por transacción.
5. **Fallback por SMS** cuando no hay datos pero sí señal de voz: un SMS con las coordenadas a un número corto.
6. **App Check y topes en el servidor** para frenar abuso real.
7. **Plan Blaze con alertas de presupuesto**, para pasar el techo de ~4.000 reportes diarios del plan gratuito.
8. **Métrica de tiempos** (recibido, despachado, atendido) para evaluar la respuesta después de un evento grande.

## 5. Cómo se simplificó el protocolo

**Qué contiene el protocolo.** 206 diapositivas: 65 tarjetas guía (16 de incendios, 2 de explosión, 40 de rescates y emergencias médicas, 7 de condiciones peligrosas), 10 procedimientos con flujo propio (RCP adulto, niño e infante; OVACE adulto, niño e infante; parto; vía aérea; torniquete; alertas infecciosas) y el interrogatorio inicial. **Las categorías 500, 800 y 900 aparecen solo en la diapositiva 1 y no tienen tarjeta.** Para ellas la app permite reportar con una descripción escrita y no muestra preguntas ni instrucciones; no se inventa nada.

**Extracción.** `tools/extract_protocolo.py` (python-pptx) copia el texto sin reescribirlo. Descarta el texto vertical decorativo y el letrero "NO CUELGUE POR FAVOR". Resuelve los 876 hipervínculos entre diapositivas a destinos concretos. `tools/verificar_protocolo.py` comprueba que **ningún párrafo útil de las diapositivas se perdió**. Se revisó a mano una muestra de tarjetas contra el volcado. Esa revisión encontró y corrigió tres fallos del extractor: una caja de preguntas que era un hipervínculo a sí misma ("Ojos"), cajas de despacho altas clasificadas como notas ("Enfermo") y una caja de texto grande tomada por título (OVACE adulto).

**Cuestionario corto.** El enunciado dice que muchas preguntas se omiten con una foto, un video o una videollamada. La regla que se aplicó: solo entra una pregunta si **una foto no la responde** y **cambia lo que hace el operador**. Quedaron:
- Tarjetas médicas (32): ¿está consciente?, ¿respira de forma normal? y ¿sexo y edad? (las tres vienen de la diapositiva 5, la continuación del interrogatorio médico), más como máximo 2 específicas de la tarjeta (sangrado, atrapados, número de heridos, convulsión actual, si puede hablar, contacto con la electricidad, si ya salió del agua).
- Las demás: como máximo 3 (atrapados, lesionados, peligro inmediato, si el fuego se propaga).
- Las preguntas del interrogatorio inicial de la diapositiva 1 (¿de qué número me llama?, ¿dónde es su emergencia?, ¿cuál es su nombre?) las responden los datos automáticos: teléfono, GPS y nombre.
- Cada pregunta es una **oración literal** del protocolo, elegida por `tools/gen_preguntas_clave.py` con patrones; nunca se escribe a mano. Hay una prueba que verifica que cada pregunta aparece en su tarjeta. Las únicas correcciones permitidas son poner el signo de apertura "¿" cuando el original lo omite y la mayúscula inicial.

**Instrucciones pre-arribo.** Se muestran **tal cual** y completas, una indicación por bloque, con letra grande. Los enlaces del protocolo ("ir a RCP adulto", "Control V.A.") son botones que abren el procedimiento. Dos cosas que se mantienen a propósito y que conviene que los Bomberos revisen: el texto está escrito para el despachador ("El Cuerpo de Bomberos está siendo despachado, a continuación le diré qué debe hacer", "llámeme de nuevo") y la app no lo adapta, porque reescribir instrucciones de salud no nos corresponde. Por eso el botón del 119 acompaña todas esas pantallas.

**Qué no se muestra al ciudadano.** Los códigos de despacho (los usa el operador, en el detalle del reporte), las preguntas internas para el despachador y las notas de despacho.

**Inconsistencias del propio PPT** (documentadas en `AUDITORIA.md`): las tarjetas "Enfermo" y "Enfermedad infecciosa" comparten el número 26; "Tipos de explosiones" es un botón sin destino; la diapositiva 188 repite el título de otra.

## 6. Arquitectura y estado

- **Por features** (`lib/features/{auth, protocolo, reportes, ciudadano, operador, videollamada}`) y un `core/` con tema, widgets y utilidades. Una estructura plana por tipo se vuelve ilegible con dos roles y cuatro dominios.
- **Provider con `ChangeNotifier`**: es lo que ya usaba la base y lo que se vio en clase. Los datos remotos entran por `Stream` de Firestore. No se agregó otra librería de estado: no hacía falta.
- **Lógica pura aparte de Flutter y Firebase** (cola, agrupación, prioridad, límite, radicado) con interfaces (`ColaStorage`, `EnvioBackend`) para probarla sin red.
- **Las claves no están en el código**: `--dart-define-from-file=config/app_config.json` (ignorado por git), más `android/secrets.properties` para Google Maps. Los `.example` listan los nombres.

## 7. Notificaciones al ciudadano

Sin Cloud Functions no hay quién envíe FCM. Se usa un listener de Firestore sobre los reportes del ciudadano (`mis_reportes.dart`) que compara cada actualización con la anterior y lanza una notificación local cuando cambia el estado o llega una videollamada. **Limitación**: solo funciona mientras el proceso de la app esté vivo (en primer plano o en segundo plano reciente). Con la app cerrada por el sistema, el ciudadano ve el cambio al abrirla. Se documenta como propuesta usar FCM con Blaze.

## 8. Diseño

- **Paleta cálida con contraste medido.** El naranja brasa `#E8590C` sobre ceniza no alcanza AA con texto blanco (3,6:1), así que los botones primarios llevan texto carbón (4,8:1) y el texto de acento usa un naranja más oscuro (`#B8430A`, 4,8:1 sobre ceniza). Texto principal 15:1. El **rojo `#B3261E`** se reserva para reportar, el 119, la prioridad crítica y finalizar una llamada. El verde solo aparece en "atendido" y en la ubicación obtenida.
- **Tipografía**: Barlow Condensed para títulos (rotulación de máquina de bomberos) y Barlow para texto, **empaquetadas** (licencia OFL). No dependen de internet, algo importante cuando la red está mala.
- **Motivos**: franja reflectiva diagonal (inicio, confirmación y configuración), separador en forma de manguera y una llama como emblema, ícono de la app y splash propios. Íconos Phosphor, uno por categoría del protocolo.
- **Bajo estrés**: el botón de reportar está en la mitad inferior de la pantalla de inicio (alcance con el pulgar); el 119 está siempre en la barra superior; áreas táctiles de al menos 48 dp; el texto respeta el tamaño de fuente del sistema; estados de carga (esqueletos), error con reintento y sin conexión (franja que explica que el reporte no se pierde); animaciones breves (trazo de la confirmación, aparición de la lista, expansión de grupos) que se reducen si el usuario desactiva las animaciones.
- **Texto**: español colombiano, de usted, frases cortas, sin emojis ni relleno.

## 9. Android

`applicationId` `co.edu.usbcali.bomberos119`, `minSdk` 24 (lo exigen Firebase, Maps y Agora), `compileSdk` 37 (lo exige `flutter_local_notifications`). Permisos pedidos al usarse con explicación previa: ubicación (formulario), cámara (fotos y video), micrófono y cámara (videollamada), notificaciones (confirmación). Si se niegan, la app ofrece una salida: escribir la dirección, elegir de la galería, o abrir los ajustes si el permiso quedó bloqueado. Para llamar al 119 y al ciudadano se abre el marcador del teléfono (`tel:`), que no requiere permiso de llamadas.

El release se firma con un keystore propio. La plantilla pedía 8 GB de memoria a Gradle; en este equipo (7,7 GB) hacía caer la compilación, se bajó a 2,5 GB en `android/gradle.properties`. El compresor de video inicial (`light_compressor`) era incompatible con el Gradle actual (sin `namespace`, dependía de Jitpack) y se cambió por `video_compress`.

## Fuentes consultadas (15 de noviembre de 2026)
- Agora, precios y minutos gratis: <https://docs.agora.io/en/video-calling/overview/pricing> y <https://docs.agora.io/en/faq/billing_free>
- Jitsi y JaaS: <https://jitsi.org/?p=2384> y <https://discuss.privacyguides.net/t/jitsi-limits-calls-to-95-min/41435.md>
- ZEGOCLOUD: <https://zegocloud.com/pricing> y <https://www.zegocloud.com/docs/console/faqs/billing/complimentary-package>
