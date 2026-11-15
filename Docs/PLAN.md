# Plan de trabajo

Un commit al final de cada fase. Estado actual en la última sección.

## Fase 0. Revisión (hecha)
`docs/AUDITORIA.md`, repositorio git, extractor y JSON del protocolo (`tools/extract_protocolo.py`, `tools/verificar_protocolo.py`, `assets/protocolo/*.json`). El verificador confirma que ningún párrafo útil de las 206 diapositivas se perdió.

## Fase 1. Base técnica y diseño
- Limpiar `lib/`, `assets/`, `test/` y plataformas no usadas. Renombrar el paquete a `bomberos_cali`.
- Android: `applicationId` `co.edu.usbcali.bomberos119`, nombre "Bomberos Cali", versión 1.0.0, permisos, minSdk 24, firma de release con keystore propio.
- Configuración sin claves en el código: `config/app_config.json` (ignorado) + `.example`, leída con `--dart-define-from-file`. La clave de Maps va en `android/secrets.properties` (ignorado) + `.example`.
- Tokens de diseño (`core/theme/tokens.dart`), `ThemeData` completo, fuentes empaquetadas, íconos, franja reflectiva, ícono de la app y splash.
- Pantalla de "configuración pendiente" para cuando falten claves.

## Fase 2. Reporte rápido (ciudadano)
- Auth con Firebase (correo y contraseña), perfil en Firestore con rol, reportar sin cuenta (anónimo de Firebase).
- Flujo: tipo de emergencia, ubicación automática, fotos y video con hoja de recomendaciones, nombre y teléfono (autollenado si hay sesión), envío.
- Primero se escribe el documento del reporte (texto y coordenadas) y después se suben los archivos. Compresión previa. Subida unsigned a Cloudinary.
- Cola offline con reintentos y retroceso exponencial. Límite de reportes por dispositivo en una ventana de tiempo.
- Respuesta automática: radicado, estado, hora. Historial con estados en tiempo real y notificaciones locales.

## Fase 3. Protocolo en la app
- Repositorio del protocolo sobre los JSON. Preguntas clave por tarjeta (solo texto copiado del protocolo, con prueba que lo verifica).
- Cuestionario corto opcional. Respuestas agregadas al mismo reporte. Prioridad automática.
- Pantalla de instrucciones pre-arribo legible bajo estrés y visor de procedimientos (RCP, OVACE, parto, etc.).
- Botón del 119 siempre visible.

## Fase 4. Radio operador
- Bandeja en tiempo real ordenada por prioridad y hora, con agrupación de reportes cercanos en distancia y tiempo.
- Mapa con todos los reportes activos. Detalle con galería, datos, respuestas, cambio de estado, enlace a Google Maps, botón de llamada.
- Videollamada con Agora: el operador crea la llamada en el documento del reporte, el ciudadano la recibe por listener y la acepta.

## Fase 5. Datos de demostración, pruebas, documentación
- Script de seed (cuentas ciudadano y operador, reportes de ejemplo) en Dart ejecutado desde la propia app en modo demo o con script Node/REST documentado.
- Reglas de Firestore en `firestore.rules`.
- Pruebas: modelo del reporte, cola offline, agrupación, parser del protocolo, prioridad.
- `flutter analyze` sin errores ni warnings.
- `SETUP.md`, `DECISIONES.md`, `GUION_DEMO.md`.

## Fase 6. APK
- Keystore propio, `flutter build apk --release` y `--split-per-abi`, instalación en dispositivo si hay uno conectado.

## Lo que depende del equipo (se deja listo para pegar el valor)
Proyecto de Firebase, clave de Google Maps con SHA-1, upload preset de Cloudinary, App ID de Agora.

## Estado
- [x] Fase 0
