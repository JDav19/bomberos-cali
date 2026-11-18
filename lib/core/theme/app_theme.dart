import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Palette.brasa,
      onPrimary: Palette.carbon,
      primaryContainer: Palette.ambarSuave,
      onPrimaryContainer: Palette.oxido,
      secondary: Palette.oxido,
      onSecondary: Colors.white,
      secondaryContainer: Palette.arenaOscura,
      onSecondaryContainer: Palette.carbon,
      tertiary: Palette.verde,
      onTertiary: Colors.white,
      error: Palette.rojo,
      onError: Colors.white,
      errorContainer: Palette.rojoSuave,
      onErrorContainer: Palette.rojo,
      surface: Palette.ceniza,
      onSurface: Palette.carbon,
      onSurfaceVariant: Palette.textoSuave,
      surfaceContainerLowest: Palette.ceniza,
      surfaceContainerLow: Palette.ceniza,
      surfaceContainer: Palette.arena,
      surfaceContainerHigh: Palette.arena,
      surfaceContainerHighest: Palette.arenaOscura,
      outline: Color(0xFF8C7F74),
      outlineVariant: Palette.arenaOscura,
      shadow: Palette.carbon,
      scrim: Palette.carbon,
      inverseSurface: Palette.carbon,
      onInverseSurface: Palette.ceniza,
      inversePrimary: Palette.ambar,
    );

    final text = _textTheme();
    final shape = RoundedRectangleBorder(borderRadius: Radii.control);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Palette.ceniza,
      canvasColor: Palette.ceniza,
      fontFamily: Fonts.body,
      textTheme: text,
      splashFactory: InkRipple.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: Palette.carbon,
        foregroundColor: Palette.ceniza,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: text.titleLarge?.copyWith(color: Palette.ceniza),
        shape: const Border(bottom: BorderSide(color: Palette.brasa, width: 3)),
      ),
      cardTheme: CardThemeData(
        color: Palette.arena,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: const BorderSide(color: Palette.arenaOscura, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Palette.brasa,
          foregroundColor: Palette.carbon,
          disabledBackgroundColor: Palette.arenaOscura,
          disabledForegroundColor: Palette.textoSuave,
          minimumSize: const Size(64, Sizes.primaryButton),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          shape: shape,
          textStyle: const TextStyle(
              fontFamily: Fonts.display, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.4),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Palette.carbon,
          minimumSize: const Size(64, Sizes.touch),
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          side: const BorderSide(color: Palette.carbon, width: Sizes.border),
          shape: shape,
          textStyle: const TextStyle(
              fontFamily: Fonts.display, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Palette.brasaOscura,
          minimumSize: const Size(64, Sizes.touch),
          shape: shape,
          textStyle: const TextStyle(
              fontFamily: Fonts.display, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Palette.carbon,
          minimumSize: const Size(Sizes.touch, Sizes.touch),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Palette.ceniza,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.l),
        labelStyle: text.bodyLarge?.copyWith(color: Palette.textoSuave),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: Palette.oxido, fontWeight: FontWeight.w600),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: Palette.rojo, fontWeight: FontWeight.w600),
        border: _inputBorder(Palette.oxido.withValues(alpha: 0.55)),
        enabledBorder: _inputBorder(Palette.oxido.withValues(alpha: 0.55)),
        focusedBorder: _inputBorder(Palette.carbon, width: 2.5),
        errorBorder: _inputBorder(Palette.rojo, width: 2),
        focusedErrorBorder: _inputBorder(Palette.rojo, width: 2.5),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Palette.arena,
        selectedColor: Palette.carbon,
        disabledColor: Palette.arena,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: Palette.ceniza),
        padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.xs),
        side: const BorderSide(color: Palette.arenaOscura),
        shape: RoundedRectangleBorder(borderRadius: Radii.chip),
        checkmarkColor: Palette.ceniza,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Palette.ceniza,
        modalBackgroundColor: Palette.ceniza,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: Palette.arenaOscura,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Palette.ceniza,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.l),
          side: const BorderSide(color: Palette.carbon, width: Sizes.border),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Palette.carbon,
        contentTextStyle: text.bodyLarge?.copyWith(color: Palette.ceniza),
        actionTextColor: Palette.ambar,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: Radii.card),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Palette.arena,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: Palette.brasa,
        indicatorShape: RoundedRectangleBorder(borderRadius: Radii.card),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 26, color: s.contains(WidgetState.selected) ? Palette.carbon : Palette.textoSuave)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: Fonts.body,
            fontSize: 13,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: Palette.carbon)),
      ),
      dividerTheme: const DividerThemeData(color: Palette.arenaOscura, thickness: 1, space: 1),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: Space.m,
        iconColor: Palette.oxido,
        contentPadding: EdgeInsets.symmetric(horizontal: Space.l),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Palette.brasa, linearTrackColor: Palette.arenaOscura),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Palette.carbon : Palette.textoSuave),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Palette.brasa : Palette.arenaOscura),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, Sizes.touch)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: Radii.control)),
          side: const WidgetStatePropertyAll(BorderSide(color: Palette.carbon, width: 1.2)),
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? Palette.carbon : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? Palette.ceniza : Palette.carbon),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontFamily: Fonts.body, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color c, {double width = Sizes.border}) =>
      OutlineInputBorder(borderRadius: Radii.control, borderSide: BorderSide(color: c, width: width));

  static TextTheme _textTheme() {
    TextStyle d(double size, FontWeight w, {double h = 1.1, double ls = 0}) => TextStyle(
        fontFamily: Fonts.display,
        fontSize: size,
        fontWeight: w,
        height: h,
        letterSpacing: ls,
        color: Palette.carbon);
    TextStyle b(double size, FontWeight w, {double h = 1.4}) =>
        TextStyle(fontFamily: Fonts.body, fontSize: size, fontWeight: w, height: h, color: Palette.carbon);
    return TextTheme(
      displaySmall: d(44, FontWeight.w700, ls: 0.2),
      headlineLarge: d(36, FontWeight.w700, ls: 0.2),
      headlineMedium: d(30, FontWeight.w700, ls: 0.2),
      headlineSmall: d(26, FontWeight.w600, h: 1.15),
      titleLarge: d(24, FontWeight.w600, h: 1.15, ls: 0.2),
      titleMedium: b(18, FontWeight.w600, h: 1.3),
      titleSmall: b(16, FontWeight.w600, h: 1.3),
      bodyLarge: b(18, FontWeight.w400),
      bodyMedium: b(16, FontWeight.w400),
      bodySmall: b(14, FontWeight.w400, h: 1.35).copyWith(color: Palette.textoSuave),
      labelLarge: b(16, FontWeight.w600, h: 1.2),
      labelMedium: b(14, FontWeight.w600, h: 1.2),
      labelSmall: b(12, FontWeight.w600, h: 1.2).copyWith(color: Palette.textoSuave, letterSpacing: 0.4),
    );
  }
}
