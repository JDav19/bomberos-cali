#!/usr/bin/env python3
"""Extrae las tarjetas guia de docs/Despacho V4 (.pptx) a JSON estructurado.

Uso (desde la raiz del repo):
    python -X utf8 tools/extract_protocolo.py

Escribe en assets/protocolo/:
  indice.json, general.json, 100_incendios.json, 200_explosion.json,
  300_rescates_medicas.json, 400_condiciones_peligrosas.json,
  500_servicio.json, 800_clima_desastres.json, 900_especial.json,
  procedimientos.json

El texto se copia tal cual del .pptx (solo se normalizan espacios).
No se reescribe ni se agrega contenido: lo que no esta en el protocolo no se pone.
Ruido que se descarta: texto vertical decorativo ("P R E G U N T A S",
"D E S P A C H O"), el letrero "NO CUELGUE POR FAVOR" y los botones de
navegacion "Siga a instrucciones pre-arribo".
"""
import glob
import json
import os
import re
import sys

from pptx import Presentation
from pptx.enum.action import PP_ACTION

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "protocolo")

# Categorias de la diapositiva 1.
CATEGORIAS = {
    "100": ("Incendios", "100_incendios.json"),
    "200": ("Explosión o ruptura sin incendio", "200_explosion.json"),
    "300": ("Rescates y emergencias médicas", "300_rescates_medicas.json"),
    "400": ("Condiciones peligrosas sin incendio", "400_condiciones_peligrosas.json"),
    "500": ("Llamadas de servicio", "500_servicio.json"),
    "800": ("Clima severo y desastres naturales", "800_clima_desastres.json"),
    "900": ("Tipo de incidente especial, no clasificado", "900_especial.json"),
}

# Tarjetas: (categoria, id, diapositiva de preguntas, [diapositivas pre-arribo]).
# Sacado de los indices (diap. 2-4) y de los titulos de cada diapositiva.
TARJETAS = [
    ("100", "incendio_edificacion", 151, [152]),
    ("100", "incendio_edificio_alto", 153, [154, 155, 156, 157]),
    ("100", "incendio_concentracion_masiva", 158, [159, 160, 161, 162]),
    ("100", "incendio_no_edificacion", 163, [164]),
    ("100", "incendio_basuras_edificacion", 165, [166]),
    ("100", "incendio_vehiculo_pasajeros", 167, [168]),
    ("100", "incendio_vehiculo_carga", 169, [170]),
    ("100", "incendio_tren", 171, [172]),
    ("100", "incendio_aeronave", 173, [174]),
    ("100", "incendio_bosque", 175, [176]),
    ("100", "incendio_arbustos_pastos", 177, [178]),
    ("100", "incendio_lote_urbano", 179, [180]),
    ("100", "incendio_basuras_exterior", 181, [182]),
    ("100", "incendio_cultivos", 183, [184]),
    ("100", "incendio_almacenaje_exterior", 185, [186]),
    ("100", "incendio_equipos_exterior", 187, [188]),
    ("200", "explosion_gas_vapor", 189, [190]),
    ("200", "ruptura_explosion", 205, [206]),
    ("300", "accidente_transito", 6, [7]),
    ("300", "accidente_industrial", 8, [9]),
    ("300", "asalto_violencia", 10, [11]),
    ("300", "caidas", 12, [13]),
    ("300", "exposicion_calor_frio", 14, [15]),
    ("300", "hemorragia", 16, [17]),
    ("300", "mordedura_animal", 18, [19]),
    ("300", "ojos", 20, [21]),
    ("300", "punalada_arma_fuego", 22, [23]),
    ("300", "quemaduras", 24, [25]),
    ("300", "trauma", 26, [27]),
    ("300", "acv", 28, [29]),
    ("300", "convulsiones", 30, [31]),
    ("300", "alergias_picaduras", 32, [33]),
    ("300", "diabetes", 34, [35]),
    ("300", "dolor_abdominal", 36, [37]),
    ("300", "dolor_cabeza", 38, [39]),
    ("300", "dolor_espalda", 40, [41]),
    ("300", "dolor_pecho", 42, [43]),
    ("300", "enfermo", 44, [45]),
    ("300", "envenenamiento", 46, [47]),
    ("300", "persona_caida", 48, [49]),
    ("300", "problemas_respiratorios", 50, [51]),
    ("300", "psiquiatrico", 52, [53]),
    ("300", "ahogamiento", 54, [55]),
    ("300", "ataque_cardiaco", 56, [57]),
    ("300", "electrocucion", 84, [85]),
    ("300", "embarazo_parto", 86, [87]),
    ("300", "inconsciente", 98, [99]),
    ("300", "inhalaciones", 104, [105]),
    ("300", "obstruccion_via_aerea", 106, [107]),
    ("300", "enfermedad_infecciosa", 130, [131]),
    ("300", "persona_encerrada", 132, [133]),
    ("300", "rescate_estructura_colapsada", 134, [135]),
    ("300", "rescate_ascensor", 136, [137]),
    ("300", "rescate_alturas", 141, [142]),
    ("300", "rescate_alturas_b", 143, [144]),
    ("300", "extraviado_zona_rural", 145, [146]),
    ("300", "vehiculo_en_agua", 147, [148]),
    ("300", "caida_en_rio", 149, [150]),
    ("400", "fuga_gas", 191, [192]),
    ("400", "olor_desconocido", 193, [194]),
    ("400", "hazmat", 195, [196]),
    ("400", "derrame_liquido", 197, [198]),
    ("400", "linea_electrica_caida", 199, [200]),
    ("400", "corto_circuito", 201, [202]),
    ("400", "estructura_colapsada_sin_atrapados", 203, [204]),
]

# Diapositivas que son procedimientos guiados (grafo de nodos), no tarjetas.
PROCEDIMIENTOS = [
    ("rcp_adulto", "RCP adulto", range(58, 68)),
    ("rcp_nino", "RCP niño", range(68, 78)),
    ("rcp_infante", "RCP infante", range(78, 84)),
    ("parto", "Instrucciones de parto", range(88, 98)),
    ("via_aerea", "Control de vía aérea - inconsciente", range(100, 104)),
    ("ovace_adulto", "OVACE adulto", range(108, 116)),
    ("ovace_nino", "OVACE niño", range(116, 124)),
    ("ovace_infante", "OVACE infante", range(124, 129)),
    ("torniquete", "Uso del torniquete", range(129, 130)),
    ("alertas_infecciosas", "Alertas COVID-19, dengue y tuberculosis", range(138, 141)),
]

NAV_TEXTS = ("siga a instrucciones pre-arribo",)


def norm(t):
    t = t.replace("\x0b", "\n").replace(" ", " ")
    t = re.sub(r"[ \t]+", " ", t)
    return t.strip()


def flatten(shapes):
    for s in shapes:
        if s.shape_type == 6:  # grupo
            yield from flatten(s.shapes)
        else:
            yield s


def is_vertical(paras):
    ps = [p for p in paras if p.strip()]
    return len(ps) >= 5 and all(len(p.strip()) == 1 for p in ps)


def paragraphs(shape):
    out = []
    for p in shape.text_frame.paragraphs:
        for part in p.text.replace("\x0b", "\n").split("\n"):
            part = norm(part)
            if part:
                out.append(part)
    return out


class Deck:
    def __init__(self, path):
        self.prs = Presentation(path)
        self.id2num = {s.slide_id: i for i, s in enumerate(self.prs.slides, 1)}

    def link(self, shape, num):
        """Devuelve (tipo, destino) o None."""
        try:
            ca = shape.click_action
            act = ca.action
            target = ca.target_slide
        except Exception:
            return None
        if target is not None:
            return ("slide", self.id2num.get(target.slide_id))
        if act == PP_ACTION.NEXT_SLIDE:
            return ("slide", num + 1)
        if act == PP_ACTION.PREVIOUS_SLIDE:
            return ("slide", num - 1)
        if act == PP_ACTION.FIRST_SLIDE:
            return ("slide", 1)
        if act == PP_ACTION.LAST_SLIDE_VIEWED:
            return ("volver", None)
        if act in (PP_ACTION.NONE, None):
            return None
        return ("otro", str(act))

    def slide_items(self, num):
        sl = self.prs.slides[num - 1]
        items = []
        for s in flatten(sl.shapes):
            if not s.has_text_frame:
                continue
            raw = [p.text for p in s.text_frame.paragraphs]
            paras = paragraphs(s)
            if not paras or is_vertical(raw):
                continue
            items.append({
                "x": s.left or 0, "y": s.top or 0, "w": s.width or 0, "h": s.height or 0,
                "paras": paras, "link": self.link(s, num),
            })
        return items


CODE_END = re.compile(r"\(\s*(\d{3})\s*\)\s*\.?\s*$")
CODE_LEAD = re.compile(r"^(\d{3})\s+(.*)$")


def is_nocuelgue(it):
    return it["paras"][0].upper().startswith("NO CUELGUE")


def is_title(it):
    return it["y"] < 700000 and it["x"] > 1000000 and it["h"] < 700000


def is_nav_link(it):
    return it["link"] is not None and it["link"][0] in ("slide", "volver")


def split_title(t):
    m = re.search(r"\((\d+)\)\s*$", t)
    num = int(m.group(1)) if m else None
    nombre = re.sub(r"\s*\(\d+\)\s*$", "", t).strip()
    return nombre, num


def lineas_tipadas(paras):
    return [{"tipo": "pregunta" if "?" in p else "texto", "texto": p} for p in paras]


def parse_dispatch(it):
    """Convierte una caja de despacho en 1..n items {codigo, descripcion}."""
    paras = it["paras"]
    if sum(1 for p in paras if CODE_LEAD.match(p)) >= 2 or (
        len(paras) == 1 and CODE_LEAD.match(paras[0])
    ):
        res = []
        for p in paras:
            m = CODE_LEAD.match(p)
            if m:
                res.append({"codigo": m.group(1), "descripcion": m.group(2)})
            elif res:
                res[-1]["descripcion"] += " " + p
            else:
                res.append({"codigo": None, "descripcion": p})
        return res
    txt = "\n".join(paras)
    m = CODE_END.search(txt)
    if m:
        desc = CODE_END.sub("", txt).strip()
        return [{"codigo": m.group(1), "descripcion": desc or txt}]
    return [{"codigo": None, "descripcion": txt}]


def extraer_tarjeta(deck, cat, tid, qnum, pre_nums):
    items = deck.slide_items(qnum)
    titulo = next((i for i in items if is_title(i)), None)
    nombre, numero = split_title(titulo["paras"][0]) if titulo else (tid, None)

    preguntas, notas, despacho, refs = [], [], [], []
    for it in items:
        if it is titulo or is_nocuelgue(it):
            continue
        if it["paras"][0].lower() in NAV_TEXTS:
            continue
        txt = " ".join(it["paras"])
        # Un cuadro que enlaza a su propia diapositiva no es una referencia.
        if is_nav_link(it) and it["link"][1] != qnum and not (it["x"] < 1500000 and it["y"] < 4200000 and "?" in txt):
            refs.append({"texto": txt, "diapositiva": it["link"][1]})
            continue
        if it["paras"] == ["Tipos de explosiones"]:
            notas.append(txt)  # boton sin diapositiva destino en el protocolo
            continue
        if it["y"] >= 4200000 or CODE_END.search(txt):
            for d in parse_dispatch(it):
                if d["descripcion"]:
                    despacho.append(d)
            continue
        if it["x"] < 1500000:
            preguntas.extend(it["paras"])
            continue
        notas.append(txt)

    pre = []
    for pn in pre_nums:
        lineas, prefs, tit = [], [], None
        for it in sorted(deck.slide_items(pn), key=lambda i: (i["y"], i["x"])):
            if is_title(it):
                tit = it["paras"][0]
                continue
            if is_nav_link(it):
                prefs.append({"texto": " ".join(it["paras"]), "diapositiva": it["link"][1]})
                continue
            lineas.extend(it["paras"])
        pre.append({"diapositiva": pn, "titulo_diapositiva": tit, "lineas": lineas,
                    "referencias": prefs})

    return {
        "id": tid, "categoria": cat, "nombre": nombre, "numero_tarjeta": numero,
        "diapositiva_preguntas": qnum, "diapositivas_pre_arribo": pre_nums,
        "preguntas": lineas_tipadas(preguntas),
        "notas": notas,
        "despacho": despacho,
        "referencias": refs,
        "pre_arribo": pre,
    }


def extraer_procedimientos(deck):
    nodos, grupos = {}, []
    for gid, gnombre, rng in PROCEDIMIENTOS:
        nums = list(rng)
        grupos.append({"id": gid, "nombre": gnombre, "entrada": nums[0], "diapositivas": nums})
        for n in nums:
            lineas, ops = [], []
            for it in sorted(deck.slide_items(n), key=lambda i: (i["y"], i["x"])):
                if is_title(it):
                    continue
                if is_nav_link(it):
                    ops.append({"texto": " ".join(it["paras"]), "destino": it["link"][1],
                                "volver": it["link"][0] == "volver"})
                else:
                    lineas.extend(it["paras"])
            nodos[str(n)] = {"diapositiva": n, "grupo": gid, "lineas": lineas, "opciones": ops}
    return {"grupos": grupos, "nodos": nodos}


def dump(name, data):
    with open(os.path.join(OUT, name), "w", encoding="utf8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def main():
    pptx = glob.glob(os.path.join(ROOT, "docs", "*.pptx"))[0]
    deck = Deck(pptx)
    os.makedirs(OUT, exist_ok=True)

    num_a_tarjeta = {}
    for _, tid, q, pres in TARJETAS:
        num_a_tarjeta[q] = tid
        for p in pres:
            num_a_tarjeta[p] = tid
    proc_a_grupo = {n: gid for gid, _, rng in PROCEDIMIENTOS for n in rng}

    def destino(d):
        if d is None:
            return None
        if d in num_a_tarjeta:
            return {"tipo": "tarjeta", "id": num_a_tarjeta[d]}
        if d in proc_a_grupo:
            return {"tipo": "procedimiento", "grupo": proc_a_grupo[d], "nodo": d}
        return {"tipo": "diapositiva", "numero": d}

    por_cat = {c: [] for c in CATEGORIAS}
    for cat, tid, q, pres in TARJETAS:
        t = extraer_tarjeta(deck, cat, tid, q, pres)
        for r in t["referencias"]:
            r["destino"] = destino(r["diapositiva"])
        for p in t["pre_arribo"]:
            for r in p["referencias"]:
                r["destino"] = destino(r["diapositiva"])
        por_cat[cat].append(t)
    # Etiquetas de cruce sin hipervinculo que nombran otra tarjeta ("Rescate en alturas B").
    nombre_a_id = {t["nombre"]: t["id"] for ts in por_cat.values() for t in ts}
    for ts in por_cat.values():
        for t in ts:
            quedan = []
            for n in t["notas"]:
                if n in nombre_a_id and nombre_a_id[n] != t["id"]:
                    t["referencias"].append({"texto": n, "diapositiva": None,
                                             "destino": {"tipo": "tarjeta", "id": nombre_a_id[n]}})
                else:
                    quedan.append(n)
            t["notas"] = quedan

    for cat, tarjetas in por_cat.items():
        nombre, fname = CATEGORIAS[cat]
        data = {"codigo": cat, "nombre": nombre, "tarjetas": tarjetas}
        if not tarjetas:
            data["nota"] = ("El protocolo adjunto solo menciona esta categoría en la "
                            "diapositiva 1; no incluye tarjetas guía para ella.")
        dump(fname, data)

    proc = extraer_procedimientos(deck)
    for n in proc["nodos"].values():
        for o in n["opciones"]:
            o["destino_info"] = destino(o["destino"]) if o["destino"] else None
    dump("procedimientos.json", proc)

    d1 = [p for it in deck.slide_items(1) if not is_title(it) for p in it["paras"]]
    d5 = [it for it in deck.slide_items(5) if not is_title(it)]
    d5s = sorted(d5, key=lambda i: (i["y"], i["x"]))
    dump("general.json", {
        "interrogatorio_toda_llamada": [p for p in d1 if "?" in p or p.startswith("Línea")],
        "interrogatorio_medico_continuacion": [
            p for it in d5s for p in it["paras"]
            if re.match(r"^\d+\.", p) or p.startswith("Interrogatorio")],
        "despacho_medico_general": [
            p for it in d5s for p in it["paras"]
            if p.startswith("Despache") or p in ("Máquina (Rescate o Bomba)", "Ambulancia")],
        "fuente_diapositivas": [1, 5],
    })

    dump("indice.json", {"fuente": os.path.basename(pptx), "categorias": [
        {"codigo": c, "nombre": n, "archivo": fn,
         "tarjetas": [{"id": t["id"], "nombre": t["nombre"]} for t in por_cat[c]]}
        for c, (n, fn) in CATEGORIAS.items()]})
    total = sum(len(v) for v in por_cat.values())
    print(f"OK: {total} tarjetas, {len(proc['nodos'])} nodos de procedimiento")


if __name__ == "__main__":
    sys.exit(main())
