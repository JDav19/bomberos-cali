import 'package:flutter/material.dart';
import 'package:bomberos_cali/core/icons/phosphor.dart';
import 'package:provider/provider.dart';

import '../../core/theme/tokens.dart';
import '../../core/util/formatters.dart';
import '../../core/widgets/comunes.dart';
import '../protocolo/protocolo.dart';
import '../reportes/envio_controller.dart';
import '../reportes/models.dart';
import 'pre_arribo_screen.dart';

/// Cuestionario corto y opcional. Solo trae las preguntas clave de la tarjeta
/// que una foto no responde. Las respuestas se agregan al mismo reporte.
class CuestionarioScreen extends StatefulWidget {
  const CuestionarioScreen({super.key, required this.reporte});

  final Reporte reporte;

  @override
  State<CuestionarioScreen> createState() => _CuestionarioScreenState();
}

class _CuestionarioScreenState extends State<CuestionarioScreen> {
  final Map<String, String> _resp = {};
  final Map<String, TextEditingController> _textos = {};
  bool _enviando = false;

  @override
  void dispose() {
    for (final c in _textos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar(List<PreguntaClave> claves, Tarjeta? tarjeta) async {
    setState(() => _enviando = true);
    final resp = {
      for (final e in _resp.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
      for (final e in _textos.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    try {
      await context.read<EnvioController>().complementar(widget.reporte, resp, claves);
      if (!mounted) return;
      avisar(context, 'Respuestas agregadas a su reporte.');
      _irAInstrucciones(tarjeta);
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      avisar(context, 'No se pudieron enviar las respuestas. Intente de nuevo.');
    }
  }

  void _irAInstrucciones(Tarjeta? tarjeta) {
    if (tarjeta == null || tarjeta.preArribo.isEmpty) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => PreArriboScreen(tarjeta: tarjeta, radicado: widget.reporte.radicado),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final protocolo = context.read<Protocolo>();
    final t = Theme.of(context).textTheme;
    final tarjeta = protocolo.tarjeta(widget.reporte.tarjetaId);
    final claves = protocolo.clavesDe(widget.reporte.tarjetaId);

    return Pantalla(
      titulo: 'Complementar',
      cuerpo: Cuerpo(hijos: [
        Text(tarjeta?.nombre ?? widget.reporte.categoriaNombre, style: t.headlineSmall),
        const SizedBox(height: Space.xs),
        Text('Responda solo lo que sepa. No se arriesgue para averiguarlo.', style: t.bodyLarge),
        const SizedBox(height: Space.xl),
        for (final q in claves) ...[
          _Pregunta(
            pregunta: q,
            valor: _resp[q.clave],
            controlador: q.tipo == TipoPregunta.texto
                ? _textos.putIfAbsent(q.clave, () => TextEditingController())
                : null,
            alCambiar: (v) => setState(() => _resp[q.clave] = v),
          ),
          const SizedBox(height: Space.xl),
        ],
        FilledButton(
          onPressed: _enviando ? null : () => _enviar(claves, tarjeta),
          child: _enviando
              ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3))
              : const Text('ENVIAR RESPUESTAS'),
        ),
        const SizedBox(height: Space.s),
        Center(
          child: TextButton(
            onPressed: _enviando ? null : () => _irAInstrucciones(tarjeta),
            child: const Text('Ahora no, ver instrucciones'),
          ),
        ),
      ]),
    );
  }
}

class _Pregunta extends StatelessWidget {
  const _Pregunta({required this.pregunta, required this.valor, required this.alCambiar, this.controlador});

  final PreguntaClave pregunta;
  final String? valor;
  final ValueChanged<String> alCambiar;
  final TextEditingController? controlador;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cuerpo = switch (pregunta.tipo) {
      TipoPregunta.siNo => Row(children: [
          for (final o in const [('si', 'Sí'), ('no', 'No'), ('nosabe', 'No sé')]) ...[
            Expanded(child: _Opcion(etiqueta: o.$2, activa: valor == o.$1, alTocar: () => alCambiar(o.$1))),
            if (o.$1 != 'nosabe') const SizedBox(width: Space.s),
          ],
        ]),
      TipoPregunta.numero => _Contador(valor: int.tryParse(valor ?? ''), alCambiar: (n) => alCambiar('$n')),
      TipoPregunta.texto => TextField(
          controller: controlador,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Escriba aquí'),
        ),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(textoPregunta(pregunta.texto), style: t.titleMedium?.copyWith(fontSize: 19)),
      const SizedBox(height: Space.m),
      cuerpo,
    ]);
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.etiqueta, required this.activa, required this.alTocar});
  final String etiqueta;
  final bool activa;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: activa,
        label: etiqueta,
        child: Material(
          color: activa ? Palette.carbon : Palette.ceniza,
          borderRadius: Radii.control,
          child: InkWell(
            borderRadius: Radii.control,
            onTap: alTocar,
            child: Container(
              height: Sizes.primaryButton,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: Radii.control,
                border: Border.all(color: Palette.carbon, width: Sizes.border),
              ),
              child: Text(etiqueta,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: activa ? Palette.ceniza : Palette.carbon)),
            ),
          ),
        ),
      );
}

class _Contador extends StatelessWidget {
  const _Contador({required this.valor, required this.alCambiar});
  final int? valor;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = valor ?? 0;
    return Row(children: [
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(Sizes.primaryButton, Sizes.primaryButton)),
        onPressed: v > 0 ? () => alCambiar(v - 1) : null,
        child: const PhosphorIcon(PhosphorIconsBold.minus),
      ),
      Container(
        width: 88,
        alignment: Alignment.center,
        child: Text(valor == null ? '—' : '$valor', style: t.displaySmall),
      ),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(Sizes.primaryButton, Sizes.primaryButton)),
        onPressed: v < 99 ? () => alCambiar(v + 1) : null,
        child: const PhosphorIcon(PhosphorIconsBold.plus),
      ),
    ]);
  }
}
