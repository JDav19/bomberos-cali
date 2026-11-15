#!/usr/bin/env python3
"""Verifica que todo el texto util de las diapositivas quedo en los JSON.

Para cada diapositiva usada (tarjetas y procedimientos) compara los parrafos
del .pptx contra los parrafos presentes en el JSON generado. Sale con codigo 1
si algun parrafo se perdio. Uso: python -X utf8 tools/verificar_protocolo.py
"""
import glob, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import extract_protocolo as E

def textos_json():
    vistos = set()
    def add(x):
        if isinstance(x, str):
            vistos.add(x)
        elif isinstance(x, dict):
            for v in x.values(): add(v)
        elif isinstance(x, list):
            for v in x: add(v)
    for f in glob.glob(os.path.join(E.OUT, "*.json")):
        add(json.load(open(f, encoding="utf8")))
    return vistos

def main():
    deck = E.Deck(glob.glob(os.path.join(E.ROOT, "docs", "*.pptx"))[0])
    vistos = textos_json()
    blob = "\n".join(vistos)
    usadas = set()
    for _, _, q, pres in E.TARJETAS:
        usadas.add(q); usadas.update(pres)
    for _, _, rng in E.PROCEDIMIENTOS:
        usadas.update(rng)
    faltan = 0
    for n in sorted(usadas):
        for it in deck.slide_items(n):
            if E.is_title(it) or E.is_nocuelgue(it) or it["paras"][0].lower() in E.NAV_TEXTS:
                continue
            for p in it["paras"]:
                if p in vistos or p in blob:
                    continue
                # puede haber sido partido (despacho con codigo al inicio/final)
                core = E.CODE_END.sub("", p).strip()
                core = E.CODE_LEAD.sub(lambda m: m.group(2), core)
                if not core or core in blob:
                    continue
                print(f"FALTA diap {n}: {p[:90]}")
                faltan += 1
    print("sin perdidas" if not faltan else f"{faltan} parrafos perdidos")
    return 1 if faltan else 0

if __name__ == "__main__":
    sys.exit(main())
