import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/estilos.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/util/servicios_dispositivo.dart';
import '../../core/widgets/categorias_ui.dart';
import '../../core/widgets/comunes.dart';
import '../../core/widgets/permisos.dart';
import '../auth/auth_service.dart';
import '../protocolo/protocolo.dart';
import '../reportes/envio_controller.dart';
import '../reportes/models.dart';
import 'confirmacion_screen.dart';
import 'hoja_recomendaciones.dart';

enum _EstadoUbic { buscando, ok, necesitaPermiso, gpsApagado, bloqueada, sinSenal }

class FormularioReporteScreen extends StatefulWidget {
  const FormularioReporteScreen({super.key, required this.categoria});

  final Categoria categoria;

  @override
  State<FormularioReporteScreen> createState() => _FormularioReporteScreenState();
}

class _FormularioReporteScreenState extends State<FormularioReporteScreen> {
  static const _maxArchivos = 6;
  static const _extVideo = {'.mp4', '.mov', '.3gp', '.mkv', '.webm', '.avi', '.m4v'};

  final _form = GlobalKey<FormState>();
  final _desc = TextEditingController();
  final _ref = TextEditingController();
  final _nombre = TextEditingController();
  final _tel = TextEditingController();
  final _picker = ImagePicker();

  Tarjeta? _tarjeta;
  Ubicacion? _ubic;
  _EstadoUbic _estadoUbic = _EstadoUbic.buscando;
  final List<ArchivoElegido> _archivos = [];
  bool _editarContacto = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    final disp = context.read<DispositivoService>();
    final p = auth.perfil;
    final deCuenta = auth.registrado && p != null && p.nombre.isNotEmpty && validarTelefono(p.telefono) == null;
    _nombre.text = deCuenta ? p.nombre : disp.nombreGuardado;
    _tel.text = deCuenta ? p.telefono : disp.telefonoGuardado;
    // Con cuenta y datos completos, el nombre y el telefono se llenan solos.
    _editarContacto = !deCuenta;
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciarUbicacion());
  }

  @override
  void dispose() {
    _desc.dispose();
    _ref.dispose();
    _nombre.dispose();
    _tel.dispose();
    super.dispose();
  }

  // ---------- Ubicacion ----------

  Future<void> _iniciarUbicacion() async {
    final st = await Permission.locationWhenInUse.status;
    if (!mounted) return;
    if (!st.isGranted) {
      setState(() => _estadoUbic = st.isPermanentlyDenied ? _EstadoUbic.bloqueada : _EstadoUbic.necesitaPermiso);
      return;
    }
    await _buscarUbicacion();
  }

  Future<void> _buscarUbicacion() async {
    setState(() => _estadoUbic = _EstadoUbic.buscando);
    final r = await context.read<UbicacionService>().obtener(pedirPermiso: false);
    if (!mounted) return;
    setState(() {
      switch (r) {
        case UbicacionObtenida(:final ubicacion):
          _ubic = ubicacion;
          _estadoUbic = _EstadoUbic.ok;
        case UbicacionFallida(:final fallo):
          _ubic = null;
          _estadoUbic = switch (fallo) {
            FalloUbicacion.gpsApagado => _EstadoUbic.gpsApagado,
            FalloUbicacion.permisoDenegado => _EstadoUbic.necesitaPermiso,
            FalloUbicacion.permisoDenegadoParaSiempre => _EstadoUbic.bloqueada,
            FalloUbicacion.sinSenal => _EstadoUbic.sinSenal,
          };
      }
    });
  }

  Future<void> _permitirUbicacion() async {
    final ok = await pedirPermisoConExplicacion(
      context,
      permiso: Permission.locationWhenInUse,
      titulo: 'Compartir su ubicación',
      motivo: 'Los Bomberos necesitan saber dónde está la emergencia. La aplicación envía las coordenadas '
          'del GPS junto con el reporte, para que no tenga que explicar la dirección.',
      icono: PhosphorIconsBold.mapPin,
      siNiega: 'Sin la ubicación tendrá que escribir la dirección y un punto de referencia.',
    );
    if (!mounted) return;
    if (ok) {
      await _buscarUbicacion();
    } else {
      final st = await Permission.locationWhenInUse.status;
      if (mounted) setState(() => _estadoUbic = st.isPermanentlyDenied ? _EstadoUbic.bloqueada : _EstadoUbic.necesitaPermiso);
    }
  }

  // ---------- Medios ----------

  Future<bool> _permisoCamara() => pedirPermisoConExplicacion(
        context,
        permiso: Permission.camera,
        titulo: 'Usar la cámara',
        motivo: 'Para tomar fotos o grabar un video de la emergencia y enviarlos a los Bomberos.',
        icono: PhosphorIconsBold.camera,
        siNiega: 'Puede elegir fotos de la galería sin dar este permiso.',
      );

  bool _esVideo(String ruta) => _extVideo.contains(ruta.toLowerCase().substring(ruta.lastIndexOf('.').clamp(0, ruta.length)));

  Future<void> _agregarMedios() async {
    if (_archivos.length >= _maxArchivos) {
      avisar(context, 'Puede enviar hasta $_maxArchivos archivos por reporte.');
      return;
    }
    final fuente = await mostrarHojaRecomendaciones(context);
    if (fuente == null || !mounted) return;
    try {
      switch (fuente) {
        case FuenteMedia.foto:
          if (!await _permisoCamara()) return;
          final x = await _picker.pickImage(source: ImageSource.camera);
          if (x != null) _agregarArchivo(x.path, TipoMedia.foto);
        case FuenteMedia.video:
          if (!await _permisoCamara()) return;
          final x = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60));
          if (x != null) _agregarArchivo(x.path, TipoMedia.video);
        case FuenteMedia.galeria:
          final restantes = _maxArchivos - _archivos.length;
          final xs = restantes >= 2
              ? await _picker.pickMultipleMedia(limit: restantes)
              : [?await _picker.pickMedia()];
          for (final x in xs) {
            _agregarArchivo(x.path, _esVideo(x.path) ? TipoMedia.video : TipoMedia.foto);
          }
      }
    } on PlatformException {
      if (mounted) avisar(context, 'No se pudo abrir la cámara o la galería. Revise los permisos del teléfono.');
    }
  }

  void _agregarArchivo(String ruta, TipoMedia tipo) {
    if (!mounted || _archivos.length >= _maxArchivos) return;
    setState(() => _archivos.add(ArchivoElegido(ruta, tipo)));
  }

  // ---------- Tipo especifico ----------

  Future<void> _elegirTarjeta() async {
    final r = await showModalBottomSheet<_EleccionTarjeta>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HojaTarjetas(categoria: widget.categoria, actual: _tarjeta),
    );
    if (r != null) setState(() => _tarjeta = r.tarjeta);
  }

  // ---------- Envio ----------

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      avisar(context, 'Revise los campos marcados.');
      return;
    }
    final envio = context.read<EnvioController>();
    setState(() => _enviando = true);
    try {
      final r = await envio.enviar(BorradorReporte(
        categoria: widget.categoria,
        tarjeta: _tarjeta,
        descripcion: _desc.text,
        referencia: _ref.text,
        nombre: _nombre.text,
        telefono: _tel.text,
        ubicacion: _ubic,
        archivos: List.of(_archivos),
      ));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => ConfirmacionScreen(radicado: r.radicado, reporteInicial: r),
      ));
    } on LimiteExcedido catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      await _mostrarLimite(e.espera);
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      avisar(context, 'No se pudo guardar el reporte. Intente de nuevo o llame al 119.');
    }
  }

  Future<void> _mostrarLimite(Duration espera) {
    final min = (espera.inSeconds / 60).ceil().clamp(1, 60);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ya envió varios reportes'),
        content: Text('Desde este teléfono se enviaron 3 reportes en los últimos 10 minutos. '
            'Podrá enviar otro en $min ${min == 1 ? 'minuto' : 'minutos'}.\n\n'
            'Si es una emergencia nueva y urgente, llame al 119.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
          FilledButton(
            style: Estilos.emergencia(alto: Sizes.touch),
            onPressed: () => Enlaces.llamar('119'),
            child: const Text('LLAMAR 119'),
          ),
        ],
      ),
    );
  }

  // ---------- Interfaz ----------

  @override
  Widget build(BuildContext context) {
    final cat = widget.categoria;
    final info = infoDe(cat.codigo);
    final t = Theme.of(context).textTheme;
    final sinTarjetas = !cat.tieneTarjetas;

    return Pantalla(
      titulo: info.etiqueta,
      cuerpo: Form(
        key: _form,
        child: Cuerpo(hijos: [
          if (!sinTarjetas) ...[
            const EncabezadoSeccion('¿Qué ocurre?'),
            _TileSeleccion(
              icono: info.icono,
              titulo: _tarjeta?.nombre ?? 'Elegir tipo (opcional)',
              subtitulo: _tarjeta == null
                  ? 'Con el tipo exacto le haremos solo las preguntas necesarias.'
                  : 'Toque para cambiar',
              onTap: _elegirTarjeta,
            ),
            const SizedBox(height: Space.l),
          ],
          TextFormField(
            controller: _desc,
            maxLines: 3,
            minLines: 2,
            maxLength: 280,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: sinTarjetas ? 'Describa lo que ocurre' : 'Algo más que quiera contar (opcional)',
            ),
            validator: (v) => sinTarjetas && (v ?? '').trim().length < 5 ? 'Escriba una descripción corta.' : null,
          ),
          const SizedBox(height: Space.l),
          const EncabezadoSeccion('Ubicación'),
          _TarjetaUbicacion(
            estado: _estadoUbic,
            ubicacion: _ubic,
            alPermitir: _permitirUbicacion,
            alReintentar: _buscarUbicacion,
          ),
          const SizedBox(height: Space.m),
          TextFormField(
            controller: _ref,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _ubic == null ? 'Dirección o punto de referencia' : 'Punto de referencia (opcional)',
              helperText: _ubic == null ? 'Sin GPS, esto es lo que usarán los Bomberos para llegar.' : null,
            ),
            validator: (v) => _ubic == null && (v ?? '').trim().length < 4
                ? 'Escriba la dirección o un lugar conocido cerca.'
                : null,
          ),
          const SizedBox(height: Space.l),
          EncabezadoSeccion('Fotos y video', trailing: Text('${_archivos.length}/$_maxArchivos', style: t.labelLarge)),
          _SeccionMedios(
            archivos: _archivos,
            alAgregar: _agregarMedios,
            alQuitar: (i) => setState(() => _archivos.removeAt(i)),
          ),
          const SizedBox(height: Space.l),
          const EncabezadoSeccion('Sus datos'),
          if (!_editarContacto)
            _ResumenContacto(
              nombre: _nombre.text,
              telefono: _tel.text,
              alCambiar: () => setState(() => _editarContacto = true),
            )
          else ...[
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Escriba su nombre.' : null,
            ),
            const SizedBox(height: Space.m),
            TextFormField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
              decoration: const InputDecoration(labelText: 'Teléfono de contacto', hintText: '3001234567'),
              validator: validarTelefono,
            ),
            const SizedBox(height: Space.s),
            Text('No necesita crear una cuenta para reportar.', style: t.bodySmall),
          ],
        ]),
      ),
      abajo: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, Space.m),
          decoration: const BoxDecoration(
            color: Palette.ceniza,
            border: Border(top: BorderSide(color: Palette.arenaOscura)),
          ),
          child: FilledButton(
            style: Estilos.emergencia(),
            onPressed: _enviando ? null : _enviar,
            child: _enviando
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                  )
                : const Text('ENVIAR REPORTE'),
          ),
        ),
      ),
    );
  }
}

class _TileSeleccion extends StatelessWidget {
  const _TileSeleccion({required this.icono, required this.titulo, required this.subtitulo, required this.onTap});

  final PhosphorIconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: Palette.arena,
      borderRadius: Radii.card,
      child: InkWell(
        borderRadius: Radii.card,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(Space.m),
          decoration: BoxDecoration(borderRadius: Radii.card, border: Border.all(color: Palette.arenaOscura)),
          child: Row(children: [
            PhosphorIcon(icono, color: Palette.oxido, size: 28),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: t.titleMedium),
                Text(subtitulo, style: t.bodySmall),
              ]),
            ),
            const PhosphorIcon(PhosphorIconsBold.caretDown, color: Palette.textoSuave),
          ]),
        ),
      ),
    );
  }
}

class _TarjetaUbicacion extends StatelessWidget {
  const _TarjetaUbicacion({
    required this.estado,
    required this.ubicacion,
    required this.alPermitir,
    required this.alReintentar,
  });

  final _EstadoUbic estado;
  final Ubicacion? ubicacion;
  final VoidCallback alPermitir;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final geo = context.read<UbicacionService>();

    final (PhosphorIconData icono, Color color, String titulo, String texto, List<Widget> acciones) = switch (estado) {
      _EstadoUbic.buscando => (
          PhosphorIconsBold.crosshair,
          Palette.oxido,
          'Buscando su ubicación…',
          'Esto toma unos segundos.',
          <Widget>[],
        ),
      _EstadoUbic.ok => (
          PhosphorIconsBold.mapPin,
          Palette.verde,
          'Ubicación lista',
          'Precisión de unos ${(ubicacion?.precisionM ?? 0).round()} m. '
              '${ubicacion!.lat.toStringAsFixed(5)}, ${ubicacion!.lng.toStringAsFixed(5)}',
          [TextButton(onPressed: alReintentar, child: const Text('Actualizar'))],
        ),
      _EstadoUbic.necesitaPermiso => (
          PhosphorIconsBold.mapPinLine,
          Palette.oxido,
          'Falta compartir la ubicación',
          'Con el GPS los Bomberos ven en un mapa dónde está la emergencia, sin que usted tenga que explicarlo.',
          [FilledButton(onPressed: alPermitir, child: const Text('Permitir ubicación'))],
        ),
      _EstadoUbic.gpsApagado => (
          PhosphorIconsBold.mapPinSimpleArea,
          Palette.rojo,
          'El GPS está apagado',
          'Actívelo en el teléfono para enviar la ubicación exacta.',
          [
            FilledButton(onPressed: geo.abrirAjustesUbicacion, child: const Text('Activar GPS')),
            TextButton(onPressed: alReintentar, child: const Text('Ya lo activé')),
          ],
        ),
      _EstadoUbic.bloqueada => (
          PhosphorIconsBold.lock,
          Palette.rojo,
          'La ubicación está bloqueada',
          'Puede activarla en los ajustes de la aplicación, o escribir la dirección abajo.',
          [const FilledButton(onPressed: openAppSettings, child: Text('Abrir ajustes'))],
        ),
      _EstadoUbic.sinSenal => (
          PhosphorIconsBold.wifiSlash,
          Palette.rojo,
          'No se obtuvo la señal GPS',
          'Pruebe de nuevo o escriba la dirección abajo.',
          [FilledButton(onPressed: alReintentar, child: const Text('Reintentar'))],
        ),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.all(Space.l),
        decoration: BoxDecoration(
          color: Palette.arena,
          borderRadius: Radii.card,
          border: Border.all(color: estado == _EstadoUbic.ok ? Palette.verde : Palette.arenaOscura, width: estado == _EstadoUbic.ok ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            PhosphorIcon(icono, color: color, size: 28),
            const SizedBox(width: Space.m),
            Expanded(child: Text(titulo, style: t.titleMedium)),
          ]),
          const SizedBox(height: Space.s),
          if (estado == _EstadoUbic.buscando) ...[
            const LinearProgressIndicator(minHeight: 4),
            const SizedBox(height: Space.s),
          ],
          Text(texto, style: t.bodyMedium),
          if (acciones.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            Wrap(spacing: Space.s, runSpacing: Space.s, children: acciones),
          ],
        ]),
      ),
    );
  }
}

class _SeccionMedios extends StatelessWidget {
  const _SeccionMedios({required this.archivos, required this.alAgregar, required this.alQuitar});

  final List<ArchivoElegido> archivos;
  final VoidCallback alAgregar;
  final void Function(int) alQuitar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (archivos.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.m),
          child: Text('Una foto o un video ayudan a los Bomberos a entender la situación. Es opcional.', style: t.bodyMedium),
        )
      else
        Padding(
          padding: const EdgeInsets.only(bottom: Space.m),
          child: Wrap(spacing: Space.s, runSpacing: Space.s, children: [
            for (var i = 0; i < archivos.length; i++)
              _Miniatura(archivo: archivos[i], alQuitar: () => alQuitar(i)),
          ]),
        ),
      OutlinedButton.icon(
        onPressed: alAgregar,
        icon: const PhosphorIcon(PhosphorIconsBold.camera),
        label: Text(archivos.isEmpty ? 'Agregar fotos o video' : 'Agregar más'),
      ),
    ]);
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.archivo, required this.alQuitar});
  final ArchivoElegido archivo;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    const lado = 96.0;
    final esFoto = archivo.tipo == TipoMedia.foto;
    return SizedBox(
      width: lado + 12,
      height: lado + 12,
      child: Stack(children: [
        Positioned(
          left: 0,
          bottom: 0,
          child: ClipRRect(
            borderRadius: Radii.card,
            child: Container(
              width: lado,
              height: lado,
              color: Palette.arenaOscura,
              child: esFoto
                  ? Image.file(File(archivo.ruta), fit: BoxFit.cover, cacheWidth: 300,
                      errorBuilder: (_, _, _) => const Center(child: PhosphorIcon(PhosphorIconsBold.image)))
                  : const Center(child: PhosphorIcon(PhosphorIconsBold.videoCamera, size: 36, color: Palette.oxido)),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: Semantics(
            button: true,
            label: 'Quitar ${esFoto ? 'foto' : 'video'}',
            child: GestureDetector(
              onTap: alQuitar,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: Sizes.touch - 8,
                height: Sizes.touch - 8,
                alignment: Alignment.topRight,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: Palette.carbon, shape: BoxShape.circle),
                  child: const Center(child: PhosphorIcon(PhosphorIconsBold.x, color: Palette.ceniza, size: 16)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ResumenContacto extends StatelessWidget {
  const _ResumenContacto({required this.nombre, required this.telefono, required this.alCambiar});
  final String nombre;
  final String telefono;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(color: Palette.arena, borderRadius: Radii.card, border: Border.all(color: Palette.arenaOscura)),
      child: Row(children: [
        const PhosphorIcon(PhosphorIconsBold.userCircle, color: Palette.oxido, size: 32),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: t.titleMedium),
            Text(telefono, style: t.bodyMedium),
          ]),
        ),
        TextButton(onPressed: alCambiar, child: const Text('Cambiar')),
      ]),
    );
  }
}

class _EleccionTarjeta {
  const _EleccionTarjeta(this.tarjeta);
  final Tarjeta? tarjeta;
}

class _HojaTarjetas extends StatefulWidget {
  const _HojaTarjetas({required this.categoria, required this.actual});
  final Categoria categoria;
  final Tarjeta? actual;

  @override
  State<_HojaTarjetas> createState() => _HojaTarjetasState();
}

class _HojaTarjetasState extends State<_HojaTarjetas> {
  String _q = '';

  static String _plano(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final lista = widget.categoria.tarjetas.where((x) => _plano(x.nombre).contains(_plano(_q))).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.s),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('¿Qué tipo es?', style: t.headlineSmall),
              const SizedBox(height: Space.m),
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar',
                  prefixIcon: Padding(padding: EdgeInsets.all(12), child: PhosphorIcon(PhosphorIconsBold.magnifyingGlass)),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(controller: scroll, padding: const EdgeInsets.only(bottom: Space.xl), children: [
              ListTile(
                minTileHeight: Sizes.touch + 8,
                title: Text('No estoy seguro', style: t.titleMedium),
                subtitle: const Text('Se envía solo la categoría'),
                onTap: () => Navigator.pop(context, const _EleccionTarjeta(null)),
              ),
              const Divider(),
              for (final x in lista)
                ListTile(
                  minTileHeight: Sizes.touch + 8,
                  title: Text(x.nombre, style: t.titleMedium),
                  trailing: widget.actual?.id == x.id ? const PhosphorIcon(PhosphorIconsBold.check, color: Palette.verde) : null,
                  onTap: () => Navigator.pop(context, _EleccionTarjeta(x)),
                ),
              if (lista.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Text('Ninguno coincide. Elija "No estoy seguro" y descríbalo.', style: t.bodyLarge),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
