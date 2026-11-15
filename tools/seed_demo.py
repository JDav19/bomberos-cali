#!/usr/bin/env python3
"""Crea las cuentas de demostracion y reportes de ejemplo en Firebase.

No necesita claves de administrador: usa la API key y el project id de
config/app_config.json, crea (o reutiliza) las dos cuentas de demostracion y
escribe los datos con sus propios tokens, asi que pasa por las reglas de
firestore.rules igual que la app.

Antes: en Firebase Console habilitar Authentication > Metodo de acceso >
Correo/contrasena y Anonimo, crear Firestore y publicar firestore.rules.

Uso (desde la raiz del repo):
    python -X utf8 tools/seed_demo.py

Conviene ejecutarlo justo antes de la demo: los reportes se fechan con la hora
actual (hace 2 min, hace 9 min...) para que la bandeja se vea viva. Se puede
repetir: los ids son fijos y se sobrescriben.

Los datos son FICTICIOS (nombres, telefonos, direcciones). Las coordenadas son
puntos reales de Cali usados solo para que el mapa tenga donde mostrar los
reportes. Las fotos son de la nube publica "demo" de Cloudinary.
"""
import datetime as dt
import json
import os
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = json.load(open(os.path.join(ROOT, "config", "app_config.json"), encoding="utf8"))
API_KEY = CFG["FIREBASE_API_KEY"]
PROJECT = CFG["FIREBASE_PROJECT_ID"]

CIUDADANO = {"correo": "ciudadano.demo@bomberoscali.app", "clave": "Demo2026!",
             "nombre": "Camila Rojas", "telefono": "3105550142"}
OPERADOR = {"correo": "operador.demo@bomberoscali.app", "clave": "Demo2026!",
            "nombre": "Operador de demostración", "telefono": ""}

DEMO = "https://res.cloudinary.com/demo"
FOTOS = [f"{DEMO}/image/upload/{n}.jpg" for n in
         ("sample", "cld-sample", "cld-sample-2", "cld-sample-3", "cld-sample-4", "cld-sample-5")]
VIDEO = f"{DEMO}/video/upload/dog.mp4"


def http(url, body=None, token=None, method=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method or ("POST" if data else "GET"))
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        raise SystemExit(f"HTTP {e.code} en {url.split('?')[0]}: {e.read().decode()[:400]}")


def cuenta(c):
    base = "https://identitytoolkit.googleapis.com/v1/accounts"
    cuerpo = {"email": c["correo"], "password": c["clave"], "returnSecureToken": True}
    try:
        return http(f"{base}:signUp?key={API_KEY}", cuerpo)
    except SystemExit as e:
        if "EMAIL_EXISTS" in str(e):
            return http(f"{base}:signInWithPassword?key={API_KEY}", cuerpo)
        raise


def fs(v):
    """Convierte un valor de Python al formato tipado de la API REST de Firestore."""
    if v is None:
        return {"nullValue": None}
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, dt.datetime):
        return {"timestampValue": v.astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")}
    if isinstance(v, str):
        return {"stringValue": v}
    if isinstance(v, list):
        return {"arrayValue": {"values": [fs(x) for x in v]}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: fs(x) for k, x in v.items()}}}
    raise TypeError(type(v))


def escribir(token, ruta, datos):
    url = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents/{ruta}"
    http(url, {"fields": {k: fs(v) for k, v in datos.items()}}, token, "PATCH")


CAT = {"100": "Incendios", "200": "Explosión o ruptura sin incendio",
       "300": "Rescates y emergencias médicas", "400": "Condiciones peligrosas sin incendio",
       "500": "Llamadas de servicio", "800": "Clima severo y desastres naturales",
       "900": "Tipo de incidente especial, no clasificado"}
PESO = {"critica": 0, "alta": 1, "media": 2, "baja": 3}

# (id, categoria, tarjetaId, tarjetaNombre, lat, lng, minutos_atras, prioridad, estado,
#  nombre, telefono, referencia/descripcion, fotos, video, respuestas, propio)
PLAZA = (3.45160, -76.53200)
REPORTES = [
    # --- Grupo: posible mismo incidente en el centro (4 reportes, <150 m, <10 min) ---
    ("001", "100", "incendio_edificio_alto", "Incendio en edificio alto", 3.45168, -76.53196, 9, "critica", "despachado",
     "Julián Martínez", "3112223344", "Humo saliendo del quinto piso, edificio de oficinas.", 3, False,
     {"atrapados": "si", "lesionados": "si"}, False),
    ("002", "100", "incendio_edificacion", "Incendio en edificación", 3.45150, -76.53215, 7, "alta", "enVerificacion",
     "Marta Lucía Prado", "3205550177", "Llamas en un local del primer piso, se ve desde la plaza.", 2, False,
     {"atrapados": "no"}, False),
    ("003", "100", "incendio_edificacion", "Incendio en edificación", 3.45178, -76.53188, 5, "alta", "recibido",
     "Andrés Velasco", "3009998877", "Mucho humo en la esquina.", 1, True, {}, False),
    ("004", "300", "persona_caida", "Persona caída / desconocido", 3.45140, -76.53170, 2, "critica", "recibido",
     "Sofía Herrera", "3151112233", "Una persona tirada en el piso, no reacciona.", 1, False,
     {"consciente": "no", "respira": "no"}, False),
    # --- Reportes sueltos ---
    ("005", "300", "accidente_transito", "Accidente de tránsito", 3.42950, -76.54600, 14, "critica", "despachado",
     "Carlos Mejía", "3187770011", "Choque entre bus y moto en la Avenida Roosevelt.", 3, True,
     {"heridos_numero": "4", "atrapados": "si", "consciente": "si", "respira": "si"}, False),
    ("006", "400", "fuga_gas", "Fuga de gas (GNC o GLP)", 3.47200, -76.52900, 22, "alta", "enVerificacion",
     "Luz Dary Castro", "3124445566", "Olor fuerte a gas en el conjunto residencial.", 0, False,
     {"se_siente_mal": "no"}, False),
    ("007", "300", "dolor_pecho", "Dolor en pecho / problemas cardiacos", 3.37640, -76.53400, 30, "alta", "despachado",
     "Camila Rojas", "3105550142", "Mi papá tiene dolor fuerte en el pecho.", 0, False,
     {"consciente": "si", "respira": "si"}, True),
    ("008", "800", None, None, 3.43000, -76.54000, 45, "media", "recibido",
     "Hernán Gil", "3016667788", "Árbol grande caído sobre la vía, tapa los dos carriles.", 2, False, {}, False),
    ("009", "300", "rescate_ascensor", "Rescate en ascensor", 3.47000, -76.50400, 60, "media", "atendido",
     "Camila Rojas", "3105550142", "Tres personas encerradas en el ascensor del edificio.", 1, False,
     {"peligro": "no", "lesionados": "no"}, True),
    ("010", "100", "incendio_lote_urbano", "Incendio en lote urbano", 3.39800, -76.52000, 120, "media", "cerrado",
     "Camila Rojas", "3105550142", "Quema de basuras en el lote de la esquina.", 1, False,
     {"propagacion": "no"}, True),
    ("011", "300", "caidas", "Caídas", 3.41500, -76.55500, 3, "alta", "recibido",
     "Patricia Ossa", "3178889900", "Señora mayor cayó de las escaleras, se queja de la cadera.", 1, False,
     {"consciente": "si", "respira": "si"}, False),
    ("012", "900", None, None, 3.43900, -76.50800, 18, "media", "enVerificacion",
     "Jorge Alzate", "3134440099", "Dron cayó en el patio de un colegio.", 0, False, {}, False),
]


def main():
    ahora = dt.datetime.now(dt.timezone.utc)
    print("Creando cuentas de demostración…")
    op = cuenta(OPERADOR)
    ci = cuenta(CIUDADANO)
    print(f"  operador   {OPERADOR['correo']}  uid={op['localId']}")
    print(f"  ciudadano  {CIUDADANO['correo']}  uid={ci['localId']}")

    escribir(op["idToken"], f"usuarios/{op['localId']}",
             {"nombre": OPERADOR["nombre"], "telefono": "", "correo": OPERADOR["correo"], "rol": "operador"})
    escribir(ci["idToken"], f"usuarios/{ci['localId']}",
             {"nombre": CIUDADANO["nombre"], "telefono": CIUDADANO["telefono"],
              "correo": CIUDADANO["correo"], "rol": "ciudadano"})

    yymmdd = ahora.astimezone().strftime("%y%m%d")
    for (n, cat, tid, tnombre, lat, lng, min_atras, prio, estado, nombre, tel, texto, nfotos, video,
         resp, propio) in REPORTES:
        rid = f"BC-{yymmdd}-DEMA{n}"
        creado = ahora - dt.timedelta(minutes=min_atras)
        media = [{"url": FOTOS[i % len(FOTOS)], "tipo": "foto", "publicId": None, "bytes": None}
                 for i in range(nfotos)]
        if video:
            media.append({"url": VIDEO, "tipo": "video", "publicId": None, "bytes": None})
        historial = [{"estado": "recibido", "en": creado, "por": "app"}]
        orden = ["recibido", "enVerificacion", "despachado", "atendido", "cerrado"]
        for k, e in enumerate(orden[1:orden.index(estado) + 1], 1):
            historial.append({"estado": e, "en": creado + dt.timedelta(minutes=2 * k), "por": op["localId"]})
        doc = {
            "radicado": rid,
            "uid": ci["localId"] if propio else f"demo-ciudadano-{n}",
            "nombre": nombre, "telefono": tel,
            "categoria": cat, "categoriaNombre": CAT[cat],
            "tarjetaId": tid, "tarjetaNombre": tnombre,
            "ubicacion": {"lat": lat, "lng": lng, "precisionM": 14.0, "automatica": True},
            "referencia": None, "descripcion": texto,
            "estado": estado, "prioridad": prio, "prioridadPeso": PESO[prio],
            "creadoEn": creado, "recibidoEn": creado,
            "media": media, "mediaPendiente": 0,
            "respuestas": resp, "cuestionarioCompleto": bool(resp),
            "videollamada": {"estado": "ninguna", "canal": None, "operadorNombre": None, "creadaEn": None},
            "historial": historial,
            "dispositivoId": "demo", "registrado": propio, "operadorUid": op["localId"] if estado != "recibido" else None,
            "nota": None,
        }
        escribir(op["idToken"], f"reportes/{rid}", doc)
        print(f"  reporte {rid}  {tnombre or CAT[cat]:<42} {prio:<8} {estado}")

    print("\nListo. Cuentas de demostración:")
    print(f"  Ciudadano: {CIUDADANO['correo']} / {CIUDADANO['clave']}")
    print(f"  Operador : {OPERADOR['correo']} / {OPERADOR['clave']}")


if __name__ == "__main__":
    sys.exit(main())
