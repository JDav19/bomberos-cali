# Bomberos Cali

Aplicación móvil (Flutter, Android) para que los ciudadanos reporten emergencias a los Bomberos Voluntarios de Cali y complementen la línea 119. Proyecto final de Aplicaciones Móviles, Universidad San Buenaventura Cali, 2026-02.

Dos roles en la misma app:
- **Ciudadano**: reporta con ubicación automática, fotos y video; recibe radicado y estado; complementa con un cuestionario corto del protocolo de despacho; ve instrucciones pre-arribo; contesta videollamadas; consulta su historial. No necesita cuenta.
- **Radio operador**: bandeja en tiempo real por prioridad, mapa de Google Maps, detalle con galería y respuestas, cambio de estado, llamada y videollamada.

## Documentación
| Archivo | Para qué |
|---|---|
| [docs/SETUP.md](docs/SETUP.md) | Crear Firebase, Google Maps, Cloudinary y Agora; correr la app; generar el APK |
| [docs/DECISIONES.md](docs/DECISIONES.md) | Decisiones técnicas con alternativas, para la sustentación |
| [docs/GUION_DEMO.md](docs/GUION_DEMO.md) | Recorrido de 5 a 7 minutos |
| [docs/AUDITORIA.md](docs/AUDITORIA.md) | Qué se encontró en la base inicial y por qué se rehízo |
| [docs/PLAN.md](docs/PLAN.md) | Fases del trabajo |

## Inicio rápido
```powershell
copy config\app_config.example.json config\app_config.json            # llenar
copy android\secrets.properties.example android\secrets.properties    # llenar
flutter pub get
flutter run --dart-define-from-file=config/app_config.json
```

## Estructura
```
lib/core/         tema (tokens, ThemeData), widgets compartidos, utilidades
lib/features/     auth, protocolo, reportes, ciudadano, operador, videollamada
assets/protocolo/ protocolo de despacho en JSON (generado desde docs/*.pptx)
tools/            extractor y verificador del protocolo, seed de demostración, íconos
firestore.rules   reglas de seguridad
test/             pruebas
```

## Protocolo de despacho
```powershell
pip install python-pptx
python -X utf8 tools/extract_protocolo.py       # .pptx -> assets/protocolo/*.json
python -X utf8 tools/verificar_protocolo.py     # ningun parrafo util se pierde
python -X utf8 tools/gen_preguntas_clave.py     # cuestionario corto (oraciones literales)
```

## Pruebas
```powershell
flutter analyze
flutter test
```
