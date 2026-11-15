# Guion de la demo (5 a 7 minutos)

Para la sustentación del 19 y 20 de noviembre ante el docente y los Bomberos.

## Antes de entrar (10 minutos antes)
- [ ] `python -X utf8 tools/seed_demo.py` (los reportes quedan fechados "hace 2 min", "hace 9 min"…).
- [ ] **Dos teléfonos** si se puede: A como ciudadano, B como operador. Con un solo teléfono, el operador se muestra cerrando sesión y entrando con la cuenta de operador (Mi cuenta → Ya tengo cuenta).
- [ ] Teléfono A: GPS encendido, datos móviles o wifi, permisos **sin conceder** (para mostrar la explicación) o ya concedidos si la sala tiene mala señal.
- [ ] Teléfono B: sesión iniciada como operador y la pestaña Mapa abierta.
- [ ] El teléfono A con 2 o 3 fotos recientes en la galería.
- [ ] Datos móviles listos para apagar (paso 5).
- [ ] Brillo al máximo, no molestar activado.

Cuentas (contraseña `Demo2026!`): `ciudadano.demo@bomberoscali.app` y `operador.demo@bomberoscali.app`.

## 1. Apertura: el problema (30 s)
> "Cuando alguien llama al 119, el radio operador tiene que preguntar barrio, dirección y punto de referencia, y buscar la coordenada para despachar. Esta app complementa la línea: el ciudadano manda la ubicación exacta, fotos y datos, y el operador ve todo en un mapa."

Mostrar la pantalla de inicio del teléfono A. Señalar: el botón rojo grande abajo (a una mano) y el **119 siempre arriba**.
> "La app no reemplaza la línea: el 119 está siempre a la vista."

## 2. Reportar sin cuenta (1 min 30 s)
1. Teléfono A, sin sesión. Tocar **Reportar emergencia** → **Emergencia médica o rescate**.
2. En el formulario: tocar **Elegir tipo** y escribir "caída" → **Caídas**.
3. La tarjeta de ubicación pide permiso con una explicación → **Permitir** → "Ubicación lista, precisión de unos 12 m".
4. Tocar **Agregar fotos o video**: aparece la **hoja de recomendaciones** (plano general primero, detalles, distancia segura, no arriesgarse). Elegir de la galería 2 fotos.
5. Escribir nombre y teléfono (se piden porque no hay cuenta) → **Enviar reporte**.

Decir: "Para reportar no obliga a crear una cuenta."

## 3. Respuesta automática y cuestionario corto (1 min)
1. Pantalla de confirmación animada: **"Su reporte fue recibido"**, **radicado `BC-…`**, estado **Recibido**, "Subiendo 2 archivos…".
2. Tocar **Complementar mi reporte**: tres o cuatro preguntas (¿está consciente?, ¿respira de forma normal?…). Contestar *No* en "respira".
3. **Enviar respuestas** → pantalla de **instrucciones pre-arribo**, letra grande, un bloque por indicación.

Decir: "Las preguntas y las instrucciones son las del protocolo de despacho, tal cual; el cuestionario es corto porque las fotos ya contestan lo demás."

## 4. El radio operador lo ve al instante (1 min 30 s)
Teléfono B.
1. En la **bandeja** el reporte nuevo aparece arriba con prioridad **Crítica** (porque contestó que no respira) y un aviso en pantalla.
2. Tocarlo: **mapa con la ubicación exacta**, botón **Abrir en Google Maps**, fotos con visor, datos del ciudadano, respuestas del cuestionario.
3. Abrir "Códigos de despacho del protocolo" (para la tarjeta Caídas).
4. Cambiar el estado a **En verificación** y luego **Despachado**.

Volver al teléfono A: el estado cambió solo y llegó una **notificación**. Abrir **Mis reportes**: línea de estados.

## 5. Videollamada (1 min)
1. Teléfono B, en el reporte: **Videollamada**.
2. Teléfono A: pantalla completa "Bomberos de Cali" → **Contestar** (pide cámara y micrófono con explicación).
3. Se ven y se escuchan. Colgar desde B.

Decir: "Elegimos Agora: 10.000 minutos gratis al mes y funciona en datos móviles sin montar servidores. Descartamos Jitsi porque ya no se puede incrustar meet.jit.si, y WebRTC propio porque sin servidor TURN no conecta en redes móviles."

## 6. Emergencia masiva (1 min)
1. Teléfono B, pestaña **Bandeja**: abrir el grupo **"Posible mismo incidente"** (4 reportes a menos de 150 m en 9 min) del centro.
2. Pestaña **Mapa**: el círculo naranja del grupo y los marcadores por prioridad.
3. Teléfono A: **apagar los datos** y enviar otro reporte con foto → aviso **"Sin conexión… se guarda en el teléfono"** y "Reporte guardado". Volver a prender los datos: el reporte aparece solo en la bandeja del operador.

Decir: "Si hay mil reportes: cola sin conexión con reintentos, el texto sale antes que las fotos, compresión, agrupación por 150 m y 15 minutos, prioridad automática y un tope de 3 reportes cada 10 minutos por teléfono."

## 7. Cierre (30 s)
- Inicio de sesión del ciudadano demo: nombre y teléfono **se llenan solos** y ve su historial.
- Dos roles en una sola app; reglas de Firestore: el ciudadano solo ve los suyos.
> "Lo que falta para producción: alertas a ciudadanos de una zona y FCM (necesitan plan Blaze), y que los Bomberos validen la tabla de prioridad."

## Si algo falla
| Problema | Salida |
|---|---|
| Sin internet en la sala | Mostrar la cola offline (paso 6.3): es el caso fuerte |
| GPS tarda en dar señal | Salir a la ventana; la app deja escribir la dirección |
| Falla la videollamada | Mostrar la llamada entrante y el botón de llamada normal al ciudadano; explicar la señalización por Firestore |
| El mapa sale gris | Falta la SHA-1 del APK en Google Cloud; mostrar el enlace "Abrir en Google Maps" |
