import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/estilos.dart';
import '../../core/theme/tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/widgets/categorias_ui.dart';
import '../../core/widgets/comunes.dart';
import '../protocolo/protocolo.dart';
import '../reportes/envio_controller.dart';
import '../reportes/models.dart';
import 'captura_medios.dart';
import 'formulario_reporte_screen.dart' show HojaTarjetas, EleccionTarjeta, SeccionMedios;
import 'reporte_rapido.dart' show nombreSinIdentificar;

/// Completa un reporte ya enviado: tipo de emergencia, descripcion, punto de
/// referencia y datos de contacto. Todo es opcional salvo el contacto, que se
/// pide para que los Bomberos puedan llamar. Actualiza el mismo reporte.
class DetallesReporteScreen extends StatefulWidget {
  const DetallesReporteScreen({super.key, required this.reporte});

  final Reporte reporte;

  @override
  State<DetallesReporteScreen> createState() => _DetallesReporteScreenState();
}

class _DetallesReporteScreenState extends State<DetallesReporteScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _desc;
  late final TextEditingController _ref;
  late final TextEditingController _nombre;
  late final TextEditingController _tel;
  late Categoria _categoria;
  Tarjeta? _tarjeta;
  final List<ArchivoElegido> _nuevos = [];
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final r = widget.reporte;
    final protocolo = context.read<Protocolo>();
    _categoria = protocolo.categoria(r.categoria) ?? protocolo.categoria('900')!;
    _tarjeta = protocolo.tarjeta(r.tarjetaId);
    _desc = TextEditingController(text: r.descripcion ?? '');
    _ref = TextEditingController(text: r.referencia ?? '');
    _nombre = TextEditingController(text: r.nombre == nombreSinIdentificar ? '' : r.nombre);
    _tel = TextEditingController(text: r.telefono);
  }

  @override
  void dispose() {
    _desc.dispose();
    _ref.dispose();
    _nombre.dispose();
    _tel.dispose();
    super.dispose();
  }

  Future<void> _elegirTarjeta() async {
    final r = await showModalBottomSheet<EleccionTarjeta>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HojaTarjetas(categoria: _categoria, actual: _tarjeta),
    );
    if (r != null) setState(() => _tarjeta = r.tarjeta);
  }

  static const _maxNuevos = 6;

  Future<void> _agregarMedios() async {
    final mas = await capturarMedios(context, restantes: _maxNuevos - _nuevos.length);
    if (!mounted || mas.isEmpty) return;
    setState(() => _nuevos.addAll(mas.take(_maxNuevos - _nuevos.length)));
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      avisar(context, 'Revise los campos marcados.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final envio = context.read<EnvioController>();
      final nuevo = await envio.actualizarDetalles(
            widget.reporte,
            nombre: _nombre.text,
            telefono: _tel.text,
            categoria: _categoria,
            tarjeta: _tarjeta,
            descripcion: _desc.text,
            referencia: _ref.text,
          );
      await envio.agregarArchivos(nuevo, List.of(_nuevos));
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
      avisar(context, 'Listo. Los Bomberos ya ven los nuevos datos.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      avisar(context, 'No se pudieron guardar los detalles. Intente de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final protocolo = context.read<Protocolo>();
    final sinUbicacion = widget.reporte.ubicacion == null;
    final sinTarjetas = !_categoria.tieneTarjetas;

    return Pantalla(
      titulo: 'Detalles del reporte',
      cuerpo: Form(
        key: _form,
        child: Cuerpo(hijos: [
          Text('Su foto y su ubicación ya llegaron. Esto ayuda a los Bomberos a prepararse; puede dejarlo '
              'para después.', style: t.bodyLarge),
          const SizedBox(height: Space.l),
          const EncabezadoSeccion('¿Qué está pasando?'),
          for (final c in protocolo.categorias) ...[
            _OpcionCategoria(
              info: infoDe(c.codigo),
              elegida: c.codigo == _categoria.codigo,
              alTocar: () => setState(() {
                if (c.codigo != _categoria.codigo) _tarjeta = null;
                _categoria = c;
              }),
            ),
            const SizedBox(height: Space.s),
          ],
          if (!sinTarjetas) ...[
            const SizedBox(height: Space.s),
            OutlinedButton.icon(
              onPressed: _elegirTarjeta,
              icon: PhosphorIcon(infoDe(_categoria.codigo).icono),
              label: Text(_tarjeta?.nombre ?? 'Elegir el tipo exacto (opcional)'),
            ),
          ],
          const SizedBox(height: Space.l),
          TextFormField(
            controller: _desc,
            maxLines: 3,
            minLines: 2,
            maxLength: 280,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Cuente qué ocurre (opcional)'),
          ),
          const SizedBox(height: Space.m),
          TextFormField(
            controller: _ref,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: sinUbicacion ? 'Dirección o punto de referencia' : 'Punto de referencia (opcional)',
              helperText: sinUbicacion ? 'No llegó el GPS: esto es lo que usarán los Bomberos para llegar.' : null,
            ),
            validator: (v) => sinUbicacion && (v ?? '').trim().length < 4
                ? 'Escriba la dirección o un lugar conocido cerca.'
                : null,
          ),
          const SizedBox(height: Space.l),
          EncabezadoSeccion('Más fotos o video', trailing: Text('${_nuevos.length}/$_maxNuevos', style: t.labelLarge)),
          SeccionMedios(
            archivos: _nuevos,
            alAgregar: _agregarMedios,
            alQuitar: (i) => setState(() => _nuevos.removeAt(i)),
          ),
          const SizedBox(height: Space.l),
          const EncabezadoSeccion('Cómo lo contactan'),
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
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                : const Text('GUARDAR DETALLES'),
          ),
        ),
      ),
    );
  }
}

class _OpcionCategoria extends StatelessWidget {
  const _OpcionCategoria({required this.info, required this.elegida, required this.alTocar});

  final InfoCategoria info;
  final bool elegida;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: elegida,
      label: info.etiqueta,
      child: Material(
        color: elegida ? Palette.ambarSuave : Palette.arena,
        borderRadius: Radii.card,
        child: InkWell(
          borderRadius: Radii.card,
          onTap: alTocar,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
            decoration: BoxDecoration(
              borderRadius: Radii.card,
              border: Border.all(color: elegida ? Palette.carbon : Palette.arenaOscura, width: elegida ? 2 : 1),
            ),
            child: Row(children: [
              PhosphorIcon(info.icono, color: Palette.oxido, size: 28),
              const SizedBox(width: Space.m),
              Expanded(child: Text(info.etiqueta, style: t.titleMedium)),
              if (elegida) const PhosphorIcon(PhosphorIconsBold.checkCircle, color: Palette.carbon),
            ]),
          ),
        ),
      ),
    );
  }
}
