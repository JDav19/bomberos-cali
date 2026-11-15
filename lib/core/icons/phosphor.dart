import 'package:flutter/widgets.dart';

/// Iconos Phosphor (MIT, ver assets/fonts/PHOSPHOR_LICENSE.txt). El paquete
/// phosphor_flutter extiende IconData, que ahora es final; se empaqueta la
/// fuente y se declaran solo los iconos usados.
typedef PhosphorIconData = IconData;

class PhosphorIcon extends StatelessWidget {
  const PhosphorIcon(this.icon, {super.key, this.size, this.color});
  final IconData icon;
  final double? size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Icon(icon, size: size, color: color);
}

abstract final class PhosphorIconsBold {
  static const arrowLeft = IconData(0xe058, fontFamily: 'PhosphorBold');
  static const arrowRight = IconData(0xe06c, fontFamily: 'PhosphorBold');
  static const arrowsOutSimple = IconData(0xe0a6, fontFamily: 'PhosphorBold');
  static const bell = IconData(0xe0ce, fontFamily: 'PhosphorBold');
  static const camera = IconData(0xe10e, fontFamily: 'PhosphorBold');
  static const cameraRotate = IconData(0xe7a4, fontFamily: 'PhosphorBold');
  static const caretDown = IconData(0xe136, fontFamily: 'PhosphorBold');
  static const caretRight = IconData(0xe13a, fontFamily: 'PhosphorBold');
  static const check = IconData(0xe182, fontFamily: 'PhosphorBold');
  static const checkCircle = IconData(0xe184, fontFamily: 'PhosphorBold');
  static const clipboardText = IconData(0xe198, fontFamily: 'PhosphorBold');
  static const cloudArrowUp = IconData(0xe1ae, fontFamily: 'PhosphorBold');
  static const cloudLightning = IconData(0xe1b2, fontFamily: 'PhosphorBold');
  static const copy = IconData(0xe1ca, fontFamily: 'PhosphorBold');
  static const crosshair = IconData(0xe1d6, fontFamily: 'PhosphorBold');
  static const eye = IconData(0xe220, fontFamily: 'PhosphorBold');
  static const eyeSlash = IconData(0xe224, fontFamily: 'PhosphorBold');
  static const fileX = IconData(0xe23c, fontFamily: 'PhosphorBold');
  static const fire = IconData(0xe242, fontFamily: 'PhosphorBold');
  static const firstAid = IconData(0xe56e, fontFamily: 'PhosphorBold');
  static const firstAidKit = IconData(0xe570, fontFamily: 'PhosphorBold');
  static const headset = IconData(0xe584, fontFamily: 'PhosphorBold');
  static const house = IconData(0xe2c2, fontFamily: 'PhosphorBold');
  static const image = IconData(0xe2ca, fontFamily: 'PhosphorBold');
  static const imageBroken = IconData(0xe7a8, fontFamily: 'PhosphorBold');
  static const images = IconData(0xe836, fontFamily: 'PhosphorBold');
  static const lifebuoy = IconData(0xe63a, fontFamily: 'PhosphorBold');
  static const listChecks = IconData(0xeadc, fontFamily: 'PhosphorBold');
  static const lock = IconData(0xe2fa, fontFamily: 'PhosphorBold');
  static const lockSimple = IconData(0xe308, fontFamily: 'PhosphorBold');
  static const magnifyingGlass = IconData(0xe30c, fontFamily: 'PhosphorBold');
  static const mapPin = IconData(0xe316, fontFamily: 'PhosphorBold');
  static const mapPinLine = IconData(0xe318, fontFamily: 'PhosphorBold');
  static const mapPinSimpleArea = IconData(0xee3c, fontFamily: 'PhosphorBold');
  static const mapTrifold = IconData(0xe31a, fontFamily: 'PhosphorBold');
  static const microphone = IconData(0xe326, fontFamily: 'PhosphorBold');
  static const microphoneSlash = IconData(0xe328, fontFamily: 'PhosphorBold');
  static const minus = IconData(0xe32a, fontFamily: 'PhosphorBold');
  static const phone = IconData(0xe3b8, fontFamily: 'PhosphorBold');
  static const plus = IconData(0xe3d4, fontFamily: 'PhosphorBold');
  static const shield = IconData(0xe40a, fontFamily: 'PhosphorBold');
  static const stack = IconData(0xe466, fontFamily: 'PhosphorBold');
  static const tray = IconData(0xe4aa, fontFamily: 'PhosphorBold');
  static const truck = IconData(0xe4b4, fontFamily: 'PhosphorBold');
  static const userCircle = IconData(0xe4c4, fontFamily: 'PhosphorBold');
  static const videoCamera = IconData(0xe4da, fontFamily: 'PhosphorBold');
  static const videoCameraSlash = IconData(0xe4dc, fontFamily: 'PhosphorBold');
  static const warningCircle = IconData(0xe4e2, fontFamily: 'PhosphorBold');
  static const warningDiamond = IconData(0xe7fc, fontFamily: 'PhosphorBold');
  static const warningOctagon = IconData(0xe4e4, fontFamily: 'PhosphorBold');
  static const wifiSlash = IconData(0xe4f2, fontFamily: 'PhosphorBold');
  static const x = IconData(0xe4f6, fontFamily: 'PhosphorBold');
}

abstract final class PhosphorIconsFill {
  static const phone = IconData(0xe3b8, fontFamily: 'PhosphorFill');
  static const phoneDisconnect = IconData(0xe3bc, fontFamily: 'PhosphorFill');
  static const play = IconData(0xe3d0, fontFamily: 'PhosphorFill');
  static const videoCamera = IconData(0xe4da, fontFamily: 'PhosphorFill');
}
