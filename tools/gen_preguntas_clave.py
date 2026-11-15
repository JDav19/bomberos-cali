#!/usr/bin/env python3
"""Selecciona las preguntas clave del cuestionario corto.

Principio: el texto NUNCA se escribe a mano. Cada pregunta es una oracion
literal tomada de las tarjetas (assets/protocolo/*.json) o de general.json.
Una "clave" es un patron que identifica una pregunta que una foto no
responde (consciencia, respiracion, atrapados, sangrado...). Si la tarjeta
no tiene una oracion que coincida, no se agrega nada.

Los efectos sobre la prioridad (sube / critica) son criterio de la APP, no del
protocolo, y se dejan en este archivo para poder ajustarlos con los Bomberos.

Uso: python -X utf8 tools/gen_preguntas_clave.py
"""
import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "assets", "protocolo")

# Tarjetas medicas: las que continuan con el interrogatorio de la diapositiva 5.
MEDICAS = {
    "accidente_transito", "accidente_industrial", "asalto_violencia", "caidas",
    "exposicion_calor_frio", "hemorragia", "mordedura_animal", "ojos", "punalada_arma_fuego",
    "quemaduras", "trauma", "acv", "convulsiones", "alergias_picaduras", "diabetes",
    "dolor_abdominal", "dolor_cabeza", "dolor_espalda", "dolor_pecho", "enfermo",
    "envenenamiento", "persona_caida", "problemas_respiratorios", "psiquiatrico",
    "ahogamiento", "ataque_cardiaco", "electrocucion", "embarazo_parto", "inconsciente",
    "inhalaciones", "obstruccion_via_aerea", "enfermedad_infecciosa",
}

# (id, tipo, regex sobre la oracion, efecto)
# efecto: {"critica": [respuestas], "sube": {respuesta: niveles}, "umbral": n}
CLAVES = [
    ("heridos_numero", "numero", r"^¿Cuántas personas ve que están heridas\?", {"umbral": 3, "sube": {"si": 1}}),
    ("atrapados", "si_no",
     r"^¿(?:Hay|hay|Alguien|alguien|La persona está|Se observan)[^?]*atrapad", {"sube": {"si": 1}}),
    ("sangrado", "si_no", r"sangrando mucho\?", {"sube": {"si": 1}}),
    ("convulsionando", "si_no", r"^¿El paciente está convulsionando en este momento\?", {"sube": {"si": 1}}),
    ("capaz_hablar", "si_no", r"^¿Es capaz de hablar o llorar\?", {"critica": ["no"]}),
    ("habla_frases", "si_no", r"^¿Es capaz de hablar frases completas\?", {"sube": {"no": 1}}),
    ("contacto_electricidad", "si_no",
     r"^¿El paciente aun está en contacto con la electricidad\?", {"sube": {"si": 1}}),
    ("fuera_del_agua", "si_no", r"^¿El paciente ya fue sacado del agua\?", {"critica": ["no"]}),
    ("peligro", "si_no",
     r"^¿Hay (?:alguien|personas) (?:atrapadas o )?en peligro inmediato\?", {"sube": {"si": 1}}),
    ("propagacion", "si_no",
     r"^¿El incendio se está propagando rápidamente\?", {"sube": {"si": 1}}),
    ("afectados", "si_no", r"^¿Hay alguien enfermo o lesionado\?", {"sube": {"si": 1}}),
    ("lesionados", "si_no", r"^¿Hay (?:alguien lesionado|personas lesionadas)\?", {"sube": {"si": 1}}),
    ("peligro_persona", "si_no", r"^¿Hay algún peligro para la persona\?", {"sube": {"si": 1}}),
    ("peligro_caer", "si_no", r"^¿Parece estar en peligro de caer\?", {"sube": {"si": 1}}),
    ("hundiendo", "si_no", r"^¿El vehículo se está hundiendo\?", {"critica": ["si"]}),
    ("se_siente_mal", "si_no", r"^¿Alguien se siente mal o está lesionado\?", {"sube": {"si": 1}}),
    ("lo_ve", "si_no", r"^¿Lo ve todavía\?", {"sube": {"no": 1}}),
    ("otro_incendio", "si_no", r"^¿El fuego del tren ha iniciado algún otro incendio\?", {"sube": {"si": 1}}),
]
MAX_ESPECIFICAS_MEDICAS = 2
MAX_OTRAS = 3


def oraciones(linea):
    """Oraciones interrogativas de una linea del protocolo, sin cambiarlas."""
    out = re.findall(r"¿[^?]*\?", linea)
    if not out and linea.rstrip().endswith("?"):
        out = [linea.strip()]
    return [o.strip() for o in out]


def main():
    general = json.load(open(os.path.join(DIR, "general.json"), encoding="utf8"))
    gm = general["interrogatorio_medico_continuacion"]
    def g(prefijo):
        for t in gm:
            if t.startswith(prefijo):
                return re.sub(r"^\d+\.\s*", "", t)  # solo se quita la numeracion
        raise SystemExit("falta en general.json: " + prefijo)
    base_medica = [
        {"clave": "consciente", "tipo": "si_no", "texto": g("7."), "fuente": 5,
         "efecto": {"critica": ["no"]}},
        {"clave": "respira", "tipo": "si_no", "texto": g("8."), "fuente": 5,
         "efecto": {"critica": ["no"]}},
        {"clave": "edad_sexo", "tipo": "texto", "texto": g("6."), "fuente": 5, "efecto": {}},
    ]

    por_tarjeta, sin_clave = {}, []
    for f in sorted(glob.glob(os.path.join(DIR, "[1-4]*.json"))):
        for t in json.load(open(f, encoding="utf8"))["tarjetas"]:
            frases = []
            for p in t["preguntas"]:
                frases += oraciones(p["texto"])
            elegidas = []
            usadas = set()
            for cid, tipo, rx, efecto in CLAVES:
                for fr in frases:
                    if fr in usadas:
                        continue
                    if re.search(rx, fr):
                        elegidas.append({"clave": cid, "tipo": tipo, "texto": fr,
                                         "fuente": t["diapositiva_preguntas"], "efecto": efecto})
                        usadas.add(fr)
                        break
            medica = t["id"] in MEDICAS
            lim = MAX_ESPECIFICAS_MEDICAS if medica else MAX_OTRAS
            elegidas = elegidas[:lim]
            por_tarjeta[t["id"]] = (base_medica if medica else []) + elegidas
            if not por_tarjeta[t["id"]]:
                sin_clave.append(t["id"])

    out = {
        "nota": ("Generado por tools/gen_preguntas_clave.py. Cada 'texto' es una oracion literal del "
                 "protocolo (solo se quito la numeracion '6.', '7.', '8.' de la diapositiva 5). "
                 "Los 'efecto' son criterio de la app para la prioridad, no del protocolo."),
        "por_tarjeta": por_tarjeta,
    }
    with open(os.path.join(DIR, "preguntas_clave.json"), "w", encoding="utf8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    n = sum(len(v) for v in por_tarjeta.values())
    print(f"{len(por_tarjeta)} tarjetas, {n} preguntas; sin preguntas clave: {sin_clave}")


if __name__ == "__main__":
    main()
