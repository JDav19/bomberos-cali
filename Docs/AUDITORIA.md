# Auditoría de la base del proyecto

Fecha de la revisión: 15 de noviembre de 2026 (sustentación: 19 y 20 de noviembre).

## 1. Qué había

La carpeta contenía una app Flutter de **películas** (consume TMDB y Rick and Morty) más material de clase suelto. No tenía relación con el proyecto de emergencias.

| Elemento | Contenido | Estado |
|---|---|---|
| `lib/` | 17 archivos: `main.dart`, `provider/movies_provider.dart`, `provider/ricky_and_morty_provider.dart`, pantallas `home_screen`, `details_screen`, `listview_screen`, widgets `card_swiper`, `movie_carousel`, modelos de TMDB, `helpers/debouncer.dart` | Funciona para películas. Nada es reutilizable para emergencias. |
| `pubspec.yaml` | `http`, `provider`, `card_swiper`, `carousel_slider`, `cupertino_icons`. SDK `^3.12.2`. Nombre `flutter_application_peliculas_202602`, versión `1.0.0+1` | Solo `provider` y `http` sirven. |
| `android/` | `applicationId` y `namespace` = `com.example.flutter_application_peliculas_202602`, `minSdk`/`targetSdk` por defecto de Flutter, release firmado con la llave **debug**. Manifiesto sin ningún permiso (ni INTERNET fuera del manifiesto de debug). `local.properties` apunta a un SDK de macOS de otra máquina | Hay que cambiar todo. Es la configuración de plantilla. |
| Firebase / backend propio | **Ninguno.** No hay `google-services.json`, ni `firebase_options.dart`, ni dependencias de Firebase | Se crea desde cero. |
| Claves o secretos | No hay claves de Google Maps ni Cloudinary en el código. `movies_provider.dart` tiene una API key de TMDB escrita en el código (línea 30) y otra en un comentario (línea 86). No pertenecen al proyecto. Se eliminan con el archivo y no se copian a ningún documento | Nada que conservar. Si esas claves son personales, conviene regenerarlas en TMDB porque ya estuvieron en texto plano. |
| `test/widget_test.dart` | Prueba del contador de Flutter | Sin valor, se reemplaza. |
| `assets/` | `loading.gif`, `no-image.jpg`, `pelicula.jpg`, `pelicula1.jpg` | Ninguno sirve. |
| `ios/ macos/ linux/ windows/ web/` | Carpetas de plataforma generadas por la plantilla | La entrega es solo Android. |
| `QR/`, `qr_readerConRoute_20261019/`, `flutter_application_reader_20261026/`, `flutter_application_reader_20261026.zip`, `Clase 2025-10-19 - Sqflite - Google Maps Flutter.docx` | Proyectos y guías de clases anteriores (lector QR, login, Sqflite, Google Maps) | No son parte del proyecto final. Se dejan en disco, se excluyen de git y del analizador. |
| `.github/modernize/`, `.idea/`, `.vscode/`, `.claude/` | Archivos de herramientas | Se excluyen de git. |
| `docs/` | `Proyecto Final de Aplicaciones Móviles 202602.docx` (enunciado) y `Despacho V4.ppsm` + `Despacho V4.ppsm.pptx` (protocolo, 206 diapositivas) | Fuente de verdad. |
| Git | No era un repositorio | Se inicializó. |

Herramientas del equipo: Flutter 3.47.4, Python 3.13 con `python-docx` 1.2.0 y `python-pptx` 1.0.2, JDK 25 (solo `keytool` en PATH), Android SDK 36 detectado por `flutter doctor`. `adb` no está en el PATH (se usa el de `platform-tools` del SDK).

## 2. Qué sirve y qué se rehace

**Se aprovecha**
- La decisión de usar **Provider** como gestión de estado (el curso y la base ya lo usan). Se mantiene.
- Paquete `http`, que se usa para la subida unsigned a Cloudinary.
- La estructura de carpetas por tipo (`models`, `provider`, `screens`, `widgets`) como punto de partida. Se reorganiza por features porque el proyecto tiene dos roles y cuatro dominios (reporte, protocolo, operador, videollamada) y una estructura plana se vuelve ilegible.

**Se rehace desde cero**
- Todo `lib/` (dominio de películas), `test/`, `assets/` y los metadatos de Android: no hay un solo archivo del dominio de emergencias, y mantener código de películas dentro de una entrega para los Bomberos sería ruido para el jurado.
- Configuración de Android: applicationId propio, minSdk fijo para los SDK de Firebase, Maps y Agora, permisos, firma de release con keystore propio.
- Tema: la base usa el tema por defecto de Material.

**Se elimina, con justificación**
- Las carpetas `ios/ macos/ linux/ windows/ web/`: la sustentación es en un Android físico, el analizador y las dependencias nativas (Agora, light_compressor) no se validan en esas plataformas y se pueden regenerar con `flutter create .`.
- `lib/` de películas, `assets/` de películas y la prueba del contador, por lo dicho arriba.

**No se toca:** el material de clase (`QR/`, zips, `.docx` de clase). No es mío para borrar.

## 3. Lectura del enunciado (extraído con python-docx)

Requisitos explícitos: coordenadas automáticas y mapa de Google Maps para el radio operador; varias fotos o videos (Cloudinary sugerido) con ventana flotante de recomendaciones; respuesta automática al ciudadano; videollamada iniciada por el operador (sugerir e implementar); sugerir qué pasa en una emergencia masiva; datos de nombre y número agilizados si hay usuario registrado; ver las emergencias reportadas; base de datos en la nube; complementar la emergencia según el protocolo. Sustentación 19 y 20 de noviembre ante el docente y los Bomberos.

Sobre `Despacho V4`: el enunciado dice que muchas preguntas se omiten con una foto, video o videollamada. Eso respalda el diseño de cuestionario corto.

**No encontré contradicciones entre el enunciado y las instrucciones de trabajo**, así que continúo sin pausa.

## 4. Lectura del protocolo (extraído con python-pptx)

- **206 diapositivas.** Las diapositivas 1 a 4 son el interrogatorio general y los índices por categoría. La 5 es la continuación del interrogatorio médico (sexo y edad, consciencia, respiración).
- **Cada tarjeta ocupa un par de diapositivas**: preguntas más códigos de despacho, y luego "instrucciones pre-arribo". Algunas tienen varias diapositivas de pre-arribo (edificio alto: 4, concentración masiva: 5).
- **Procedimientos con flujo propio** (se navegan con botones SI/NO/OK): RCP adulto (58-67), niño (68-77) e infante (78-83), parto (88-97), control de vía aérea (100-103), OVACE adulto (108-115), niño (116-123) e infante (124-128), torniquete (129) y alertas infecciosas (138-140).
- **Hay 876 hipervínculos** entre diapositivas ("Ir a Hemorragia / laceración", "Instrucciones RCP - ADULTO"). Se resuelven a un destino concreto (tarjeta o nodo de procedimiento).
- **Ruido decorativo**: texto vertical letra por letra ("P R E G U N T A S", "D E S P A C H O") y el letrero "NO CUELGUE POR FAVOR, YA SIGO CON USTED". Se descartan.
- **Códigos de despacho**: son números de tres dígitos entre paréntesis al final de cada condición ("Dificultad respiratoria (321)"). No hay un nivel de prioridad explícito en el texto. Los colores de las cajas no son consistentes entre tarjetas (hay 18 colores distintos), así que **no se infiere prioridad del color**.
- **Solo hay tarjetas para 100, 200, 300 y 400.** Las categorías **500, 800 y 900 aparecen únicamente como una línea en la diapositiva 1; no tienen tarjeta guía**. Consecuencia: para esas categorías la app permite reportar, pero no inventa cuestionario ni instrucciones (ver `DECISIONES.md`).
- **Inconsistencias del propio PPT** que se documentan y no se corrigen en el contenido: el índice de Incendios lista "Ataque cardíaco" en la columna de Vegetación; la diapositiva 188 (pre-arribo de equipos en exterior) lleva el título "almacenaje en exterior" y repite el texto de la 186; "Accidente de tránsito, limpieza general" figura en el índice 400 sin tarjeta; el botón "Tipos de explosiones" (diap. 205) no enlaza a nada; la tarjeta 26 se repite como número en "Enfermo" y "Enfermedad infecciosa".
- **Texto escrito para el despachador**, no para el ciudadano ("Llámeme de nuevo", "El Cuerpo de Bomberos está siendo despachado, a continuación le diré qué debe hacer"). Se muestra tal cual, como exige el encargo, y la app deja el botón del 119 siempre visible.

## 5. Riesgos que veo desde ya

1. **Firebase, Google Maps, Cloudinary y Agora requieren cuentas y claves del equipo.** No las puedo crear yo. Se deja todo parametrizado por un archivo ignorado por git y se entrega la lista de pendientes.
2. **Prueba en dispositivo**: `adb` no está en el PATH y hay que verificar si hay un teléfono conectado antes de prometer una prueba de flujo completo.
3. **Tiempo**: quedan cuatro días hasta la sustentación. El plan prioriza el flujo de punta a punta sobre el pulido.
