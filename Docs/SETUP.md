# Puesta en marcha

Todo lo que necesita una cuenta o clave suya está aquí, en orden. Al terminar tendrá `config/app_config.json` y `android/secrets.properties` llenos y la app corriendo en un Android.

**Datos fijos del proyecto**
- applicationId (Android): `co.edu.usbcali.bomberos119`
- Nombre de la app: Bomberos Cali · Versión: 1.0.0

## 0. Requisitos en el computador
- Flutter 3.47 (`flutter doctor` sin errores) y Android SDK. Si `adb` no está en el PATH: `C:\Users\<usuario>\AppData\Local\Android\sdk\platform-tools\adb.exe`.
- Python 3 (solo para el protocolo y el seed). Para regenerar el protocolo: `pip install python-pptx python-docx`.
- Un teléfono Android con depuración USB activada.

## 1. Firebase (Authentication + Firestore)

No use Firebase Storage ni Cloud Functions: exigen el plan Blaze. Con el plan gratuito Spark alcanza todo lo de esta app.

1. En <https://console.firebase.google.com> cree un proyecto (por ejemplo `bomberos-cali-usb`). Puede desactivar Google Analytics.
2. **Authentication → Método de acceso**: habilite **Correo electrónico/contraseña** y **Anónimo**. El acceso anónimo es lo que permite reportar sin crear cuenta.
3. **Firestore Database → Crear base de datos** en modo producción, región `southamerica-east1` (São Paulo) o la más cercana.
4. **Firestore → Reglas**: pegue el contenido de [`firestore.rules`](../firestore.rules) y publique.
5. Registre la app Android: **Configuración del proyecto → Tus apps → Android** con el nombre de paquete `co.edu.usbcali.bomberos119` y las huellas SHA-1 (paso 2.2). No hace falta descargar `google-services.json`.
6. Copie los valores a `config/app_config.json` (parta de `config/app_config.example.json`):

| Variable | Dónde está |
|---|---|
| `FIREBASE_API_KEY` | Configuración del proyecto → General → "Clave de API web" (es la misma que trae `google-services.json` como `current_key`) |
| `FIREBASE_APP_ID` | Configuración del proyecto → General → Tus apps → Android → "ID de la app" (`1:123…:android:abc…`) |
| `FIREBASE_MESSAGING_SENDER_ID` | Configuración del proyecto → Cloud Messaging → "ID del remitente" (es el número del proyecto, `project_number`) |
| `FIREBASE_PROJECT_ID` | Configuración del proyecto → General → "ID del proyecto" |

**Alternativa con `flutterfire configure`:** instale la CLI (`dart pub global activate flutterfire_cli`), ejecute `flutterfire configure --project=<su-proyecto> --platforms=android --android-package-name=co.edu.usbcali.bomberos119` y copie `apiKey`, `appId`, `messagingSenderId` y `projectId` del `lib/firebase_options.dart` que genera a `config/app_config.json`. Después puede borrar ese archivo: esta app construye las opciones de Firebase desde `app_config.json` para que ninguna clave quede en el código.

## 2. Google Maps (mapa del radio operador)

1. En <https://console.cloud.google.com> use el mismo proyecto de Firebase (o uno nuevo con facturación activada: Maps pide tarjeta, pero el uso de una demo cae dentro del crédito mensual gratuito).
2. **APIs y servicios → Biblioteca → Maps SDK for Android → Habilitar.**
3. **Credenciales → Crear credencial → Clave de API.** Restringirla: *Restricciones de aplicaciones → Apps Android* y agregue `co.edu.usbcali.bomberos119` con cada huella SHA-1.
4. Huellas SHA-1 (cree una entrada por cada una):
   - Debug: `keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android`
   - Release: `keytool -list -v -keystore android\app\bomberos-release.jks -alias bomberos` (la contraseña está en `android/key.properties`).
   - Si el mapa sale en blanco en el APK de release, casi siempre falta la SHA-1 de release.
5. Copie `android/secrets.properties.example` a `android/secrets.properties` y pegue la clave en `MAPS_API_KEY`.

## 3. Cloudinary (fotos y videos)

1. Cree una cuenta gratuita en <https://cloudinary.com>. En el panel anote el **Cloud name**.
2. **Settings → Upload → Upload presets → Add upload preset**:
   - *Signing mode*: **Unsigned**.
   - *Folder*: `reportes`.
   - *Allowed formats*: `jpg,jpeg,png,heic,mp4,mov,3gp,webm`.
   - Guarde y anote el nombre del preset.
3. Pegue `CLOUDINARY_CLOUD_NAME` y `CLOUDINARY_UPLOAD_PRESET` en `config/app_config.json`. No hay clave secreta en la app: es la razón de usar subida unsigned.

## 4. Videollamada (Agora)

1. Cree una cuenta en <https://console.agora.io> y un proyecto de **Video Calling**.
2. Para la demo, cree el proyecto con autenticación **solo App ID** (sin App Certificate). Así la app entra a los canales sin servidor de tokens.
   - Si su consola solo permite proyectos con certificado, hay que usar un **token temporal** (consola → su proyecto → Generar token temporal) para el canal que va a usar. Ese token vale para un canal y 24 horas. Péguelo en `AGORA_TEMP_TOKEN` y use el radicado exacto como nombre del canal. No es práctico para una demo con reportes nuevos; por eso se recomienda App ID solo.
3. Pegue `AGORA_APP_ID` en `config/app_config.json`.

Verificación pendiente: no pude probar la consola de Agora desde aquí, así que el paso 2 (proyecto sin certificado) está escrito según su documentación y debe confirmarlo usted al crear el proyecto.

## 5. Correr la app

```powershell
cd "d:\U\Semestre 7\Moviles\flutter_application_peliculas_202602"
copy config\app_config.example.json config\app_config.json      # y llénelo
copy android\secrets.properties.example android\secrets.properties
flutter pub get
flutter run --dart-define-from-file=config/app_config.json
```

Si arranca y muestra "Falta configurar la aplicación", alguna variable de Firebase está vacía; la pantalla dice cuál.

## 6. Cuentas y datos de demostración

```powershell
python -X utf8 tools/seed_demo.py
```

Crea (o reutiliza) estas cuentas y 12 reportes de ejemplo fechados con la hora actual. Hágalo justo antes de la demo.

| Rol | Correo | Contraseña |
|---|---|---|
| Ciudadano | `ciudadano.demo@bomberoscali.app` | `Demo2026!` |
| Radio operador | `operador.demo@bomberoscali.app` | `Demo2026!` |

El rol de operador está en Firestore: `usuarios/<uid>` con `rol: "operador"`. Para convertir a otra persona en operador, edite ese campo en la consola. La regla `esCuentaOperadorDemo` de `firestore.rules` permite crear la cuenta de demostración sin consola; **bórrela antes de cualquier uso real**.

## 7. APK de producción

### Keystore propio (una sola vez)
```powershell
keytool -genkeypair -v -keystore android\app\bomberos-release.jks -alias bomberos -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Bomberos Cali, OU=Aplicaciones Moviles, O=Universidad San Buenaventura Cali, L=Cali, C=CO"
copy android\key.properties.example android\key.properties   # y ponga las contraseñas que usó
```
`android/key.properties` y el `.jks` están en `.gitignore`. **Haga una copia de seguridad del `.jks` y de la contraseña**: sin ellos no se puede actualizar la app instalada con otra firma.

Para regenerarlo, borre el `.jks`, repita el comando y registre la nueva huella SHA-1 en Google Cloud (paso 2.4). Los teléfonos con el APK anterior deberán desinstalarlo.

### Compilar
```powershell
flutter build apk --release --dart-define-from-file=config/app_config.json
flutter build apk --release --split-per-abi --dart-define-from-file=config/app_config.json
```
Salida en `build\app\outputs\flutter-apk\`: `app-release.apk` (universal) y `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk`. Un teléfono actual usa el de `arm64-v8a`.

### Instalar
```powershell
flutter install --release -d <id-del-dispositivo>      # ver ids con: flutter devices
```

## 8. Si algo falla

| Síntoma | Causa probable |
|---|---|
| "No pudimos iniciar" al abrir | Autenticación anónima sin habilitar, o sin internet |
| El operador ve "No se pudieron leer los reportes" | La cuenta no tiene `rol: "operador"`, o no se publicaron las reglas |
| Mapa en blanco | Falta `MAPS_API_KEY`, o falta la SHA-1 del keystore con el que se firmó |
| Las fotos no suben (quedan "por llegar") | Preset de Cloudinary mal escrito o no es *Unsigned* |
| "La videollamada no está configurada" | Falta `AGORA_APP_ID` |
| `Gradle` pide desugaring o falla por JDK | Use el JDK 17 o 21 que trae `flutter doctor`, no el JDK 25 |
