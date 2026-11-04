import 'package:flutter/material.dart';

import '../logic/models.dart';
import '../state/app_state.dart';

const _font = 'NotoSansJP';

/// Large, high-legibility type scale (before the user's text-size setting is applied).
TextTheme _textTheme(Color ink) => TextTheme(
      displaySmall: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, height: 1.15, color: ink),
      headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.25, color: ink),
      headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.3, color: ink),
      titleLarge: TextStyle(fontSize: 23, fontWeight: FontWeight.w700, height: 1.3, color: ink),
      titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.35, color: ink),
      bodyLarge: TextStyle(fontSize: 20, height: 1.5, color: ink),
      bodyMedium: TextStyle(fontSize: 18, height: 1.5, color: ink),
      bodySmall: TextStyle(fontSize: 16, height: 1.45, color: ink),
      labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
      labelMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ink),
    ).apply(fontFamily: _font); // so buttons and app bars use the bundled font too

ThemeData buildTheme(Display display) {
  final scheme = switch (display) {
    Display.light => ColorScheme.fromSeed(seedColor: const Color(0xFF1F5FBF), surface: const Color(0xFFFAFAF8)),
    Display.dark => ColorScheme.fromSeed(seedColor: const Color(0xFF1F5FBF), brightness: Brightness.dark, surface: const Color(0xFF151515)),
    Display.contrast => const ColorScheme.light(
        primary: Color(0xFF0033A0),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFDCE6FF),
        onPrimaryContainer: Colors.black,
        secondaryContainer: Color(0xFFE8E8E8),
        onSecondaryContainer: Colors.black,
        surface: Colors.white,
        onSurface: Colors.black,
        onSurfaceVariant: Colors.black,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: Colors.white,
        surfaceContainer: Colors.white,
        surfaceContainerHigh: Color(0xFFF2F2F2),
        outline: Colors.black,
        outlineVariant: Color(0xFF444444),
        error: Color(0xFFB00020),
      ),
  };
  final hc = display == Display.contrast;
  final border = BorderSide(color: hc ? Colors.black : scheme.outlineVariant, width: hc ? 2 : 1);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  const minButton = Size(64, 64);
  const pad = EdgeInsets.symmetric(horizontal: 24, vertical: 14);
  final labelStyle = _textTheme(scheme.onSurface).labelLarge;

  return ThemeData(
    colorScheme: scheme,
    fontFamily: _font,
    textTheme: _textTheme(scheme.onSurface),
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      toolbarHeight: 72,
      titleTextStyle: _textTheme(scheme.onSurface).headlineSmall,
      shape: hc ? const Border(bottom: BorderSide(width: 2)) : null,
    ),
    cardTheme: CardThemeData(
      color: hc ? Colors.white : scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: border),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: minButton, padding: pad, shape: shape, textStyle: labelStyle)),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: minButton, padding: pad, shape: shape, textStyle: labelStyle, side: BorderSide(color: scheme.primary, width: 2)),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(56, 56), padding: pad, textStyle: labelStyle)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: hc ? Colors.white : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: border),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: border),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 3)),
      labelStyle: const TextStyle(fontSize: 18),
      hintStyle: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 84,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      backgroundColor: hc ? Colors.white : scheme.surfaceContainer,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: _font,
            fontSize: 16,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: scheme.onSurface,
          )),
      iconTheme: WidgetStateProperty.all(IconThemeData(size: 30, color: scheme.onSurface)),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineWidth: WidgetStateProperty.all(2),
      trackOutlineColor: WidgetStateProperty.all(hc ? Colors.black : scheme.outline),
    ),
    dividerTheme: DividerThemeData(color: hc ? Colors.black : scheme.outlineVariant, thickness: hc ? 2 : 1),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, contentTextStyle: _textTheme(Colors.white).bodyLarge),
  );
}

/// Status colors, always paired with an icon and words (never color alone).
({Color color, IconData icon}) statusStyle(Status s, Brightness b) {
  final dark = b == Brightness.dark;
  return switch (s) {
    Status.good => (color: dark ? const Color(0xFF6BD36B) : const Color(0xFF1B7A1B), icon: Icons.check_circle),
    Status.tight => (color: dark ? const Color(0xFFFFC940) : const Color(0xFF8A5A00), icon: Icons.error),
    Status.short => (color: dark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E), icon: Icons.cancel),
    Status.high => (color: dark ? const Color(0xFFFFAB66) : const Color(0xFFA34700), icon: Icons.arrow_circle_up),
    Status.none => (color: Colors.grey, icon: Icons.remove),
  };
}

/// Group colors for the bar chart (distinct in color-blind vision; always labelled with text too).
Color groupColor(Group g, Brightness b) => switch (g) {
      Group.needs => b == Brightness.dark ? const Color(0xFF5B9BEA) : const Color(0xFF1F5FBF),
      Group.wants => b == Brightness.dark ? const Color(0xFFF08A5D) : const Color(0xFFD9541E),
      Group.savings => b == Brightness.dark ? const Color(0xFF3CC08F) : const Color(0xFF158A60),
    };

IconData categoryIcon(String id) => switch (id) {
      'housing' => Icons.home_rounded,
      'utilities' => Icons.lightbulb_rounded,
      'groceries' => Icons.shopping_basket_rounded,
      'transportation' => Icons.directions_bus_rounded,
      'carPayment' => Icons.directions_car_rounded,
      'healthcare' => Icons.local_hospital_rounded,
      'childcare' => Icons.child_care_rounded,
      'debt' => Icons.credit_card_rounded,
      'buffer' => Icons.umbrella_rounded,
      'dining' => Icons.restaurant_rounded,
      'entertainment' => Icons.palette_rounded,
      'personal' => Icons.checkroom_rounded,
      'subscriptions' => Icons.subscriptions_rounded,
      'emergency' => Icons.health_and_safety_rounded,
      'investing' => Icons.savings_rounded,
      _ => Icons.edit_note_rounded,
    };
