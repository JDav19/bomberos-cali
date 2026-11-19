"""Prueba de videollamada con un solo celular.

El computador hace de RADIO OPERADOR: inicia sesion con la cuenta demo, marca el
reporte como "llamando" (igual que la app del operador) y abre una pagina que
entra al canal con la camara del PC (uid 1001). El celular, con la sesion del
ciudadano que envio el reporte, recibe la llamada entrante y la contesta.

Uso:  python -X utf8 tools/prueba_agora_web.py BC-261118-XXXXXXX
Lee AGORA_APP_ID y AGORA_APP_CERTIFICATE de config/app_config.json (ignorado por git).
"""
import urllib.request, base64, hashlib, hmac, http.server, json, os, struct, sys, time, zlib, webbrowser, random

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def u16(v): return struct.pack('<H', v)
def u32(v): return struct.pack('<I', v)
def texto(b): b = b.encode() if isinstance(b, str) else b; return u16(len(b)) + b


def token(app_id, cert, canal, uid, vigencia=7200):
    ts = int(time.time()); salt = random.randint(1, 0xFFFFFFFF)
    k = hmac.new(u32(ts), cert.encode(), hashlib.sha256).digest()
    k = hmac.new(u32(salt), k, hashlib.sha256).digest()
    serv = u16(1) + u16(4) + b''.join(u16(p) + u32(vigencia) for p in (1, 2, 3, 4)) + texto(canal) + texto(str(uid))
    info = texto(app_id) + u32(ts) + u32(vigencia) + u32(salt) + u16(1) + serv
    firma = hmac.new(k, info, hashlib.sha256).digest()
    return '007' + base64.b64encode(zlib.compress(texto(firma) + info)).decode()


PAGINA = """<!doctype html><meta charset=utf-8><title>Operador (prueba)</title>
<body style="font-family:sans-serif;background:#121212;color:#F8F6F1;padding:16px">
<h2>Operador de prueba &middot; canal __CANAL__</h2><p id=estado>Conectando...</p><p id=niveles></p><button id=aud style='font-size:18px;padding:10px'>Activar audio</button>
<div style="display:flex;gap:12px"><div><p>Ciudadano (celular)</p><div id=remoto style="width:320px;height:240px;background:#000"></div></div></div>
<script src="https://download.agora.io/sdk/release/AgoraRTC_N-4.22.0.js"></script>
<script>
(async()=>{const e=document.getElementById('estado');const log=t=>{e.textContent=t;fetch('/log?m='+encodeURIComponent(t));};
try{const c=AgoraRTC.createClient({mode:'rtc',codec:'vp8'});
c.on('user-published',async(u,t)=>{await c.subscribe(u,t);if(t==='video')u.videoTrack.play('remoto');if(t==='audio')u.audioTrack.play();log('Conectado con el ciudadano: llegó '+t);});
c.on('user-left',()=>log('El ciudadano salió'));
await c.join('__APPID__','__CANAL__','__TOKEN__',1001);
const m=await AgoraRTC.createMicrophoneAudioTrack();await c.publish([m]);let ra=null;c.on('user-published',(u,t)=>{if(t==='audio')ra=u.audioTrack;});setInterval(()=>{const a=Math.round(m.getVolumeLevel()*100),b=ra?Math.round(ra.getVolumeLevel()*100):-1;document.getElementById('niveles').textContent='Micrófono PC: '+a+' | Audio del celular: '+b;fetch('/log?m='+encodeURIComponent('nivel mic PC='+a+' audio celular='+b));},3000);document.getElementById('aud').onclick=()=>{if(ra)ra.play();};
log('Dentro del canal. Esperando que conteste el celular...');}
catch(err){log('ERROR: '+(err.code||'')+' '+err.message);}})();
</script>"""


def peticion(url, datos, metodo='POST', cabeceras=None):
    r = urllib.request.Request(url, json.dumps(datos).encode(), {'Content-Type': 'application/json', **(cabeceras or {})}, method=metodo)
    with urllib.request.urlopen(r, timeout=20) as f:
        return json.load(f)


def llamar(cfg, canal):
    """Inicia sesion como operador demo y deja el reporte en estado 'llamando'."""
    a = peticion('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + cfg['FIREBASE_API_KEY'],
                 {'email': 'operador.demo@bomberoscali.app', 'password': 'Demo2026!', 'returnSecureToken': True})
    doc = 'https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/reportes/%s' % (cfg['FIREBASE_PROJECT_ID'], canal)
    ahora = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    peticion(doc + '?updateMask.fieldPaths=videollamada', {'fields': {'videollamada': {'mapValue': {'fields': {
        'estado': {'stringValue': 'llamando'}, 'canal': {'stringValue': canal},
        'operadorNombre': {'stringValue': 'Operador demo (PC)'}, 'creadaEn': {'timestampValue': ahora}}}}}},
        metodo='PATCH', cabeceras={'Authorization': 'Bearer ' + a['idToken']})
    print('Llamada iniciada. Conteste en el celular.')


def main():
    if len(sys.argv) < 2:
        sys.exit('Falta el radicado (canal). Ej: python -X utf8 tools/prueba_agora_web.py BC-261118-ABCDEFG')
    canal = sys.argv[1]
    cfg = json.load(open(os.path.join(RAIZ, 'config', 'app_config.json'), encoding='utf-8'))
    html = (PAGINA.replace('__CANAL__', canal).replace('__APPID__', cfg['AGORA_APP_ID'])
            .replace('__TOKEN__', token(cfg['AGORA_APP_ID'], cfg['AGORA_APP_CERTIFICATE'], canal, 1001))).encode()

    class H(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path.startswith('/log'):
                from urllib.parse import urlparse, parse_qs
                print('PAGINA:', parse_qs(urlparse(self.path).query).get('m', [''])[0], flush=True)
                self.send_response(204); self.end_headers(); return
            self.send_response(200); self.send_header('Content-Type', 'text/html; charset=utf-8'); self.end_headers()
            self.wfile.write(html)
        def log_message(self, *a): pass

    llamar(cfg, canal)
    srv = http.server.HTTPServer(('127.0.0.1', 8765), H)
    print('Abriendo http://localhost:8765  (Ctrl+C para salir)')
    webbrowser.open('http://localhost:8765')
    srv.serve_forever()


main()
