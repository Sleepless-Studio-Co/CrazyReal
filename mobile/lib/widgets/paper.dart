import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared "warm paper" design tokens, in a light and a dark variant.
///
/// Pages read them with `context.paper` so they follow the app theme mode.
/// Every colour used on text or icons is checked against its background for
/// a WCAG AA contrast ratio (4.5:1 for body text, 3:1 for large text/icons),
/// see test/theme/paper_contrast_test.dart.
@immutable
class PaperColors extends ThemeExtension<PaperColors> {
  const PaperColors({
    required this.bg,
    required this.card,
    required this.border,
    required this.chip,
    required this.ink,
    required this.inkMuted,
    required this.accent,
    required this.danger,
    required this.success,
    required this.field,
    required this.fieldBorder,
    required this.placeholder,
    required this.shadow,
    required this.heroStart,
    required this.heroEnd,
  });

  final Color bg;
  final Color card;
  final Color border;
  final Color chip;
  final Color ink;
  final Color inkMuted;

  /// Accent/danger/success used as text or icon colour on paper surfaces.
  /// For filled buttons and snackbars under white text, use the fixed
  /// [paperAccentStrong], [paperDanger] and [paperSuccess] instead.
  final Color accent;
  final Color danger;
  final Color success;

  /// Inset surfaces: text fields, search results, chips on a card.
  final Color field;
  final Color fieldBorder;

  /// Background shown while an image loads.
  final Color placeholder;
  final Color shadow;

  /// Gradient of highlighted header cards (account profile).
  final Color heroStart;
  final Color heroEnd;

  static const light = PaperColors(
    bg: Color(0xFFF7EBD1),
    card: Color(0xFFFFF7E6),
    border: Color(0xFFF0DFC2),
    chip: Color(0xFFF0DFC2),
    ink: Color(0xFF3B2A21),
    inkMuted: Color(0xFF6A4A3B),
    accent: Color(0xFF9E4A2C),
    danger: Color(0xFFB54132),
    success: Color(0xFF2F6B4F),
    field: Color(0xFFFFFFFF),
    fieldBorder: Color(0xFFE7D3B5),
    placeholder: Color(0xFFEEDCC5),
    shadow: Color(0x1F2E1B0F),
    heroStart: Color(0xFFFFF2D9),
    heroEnd: Color(0xFFF0D0A8),
  );

  static const dark = PaperColors(
    bg: Color(0xFF171311),
    card: Color(0xFF231C18),
    border: Color(0xFF3A2E27),
    chip: Color(0xFF3A2E27),
    ink: Color(0xFFF4E7D4),
    inkMuted: Color(0xFFC8B4A2),
    accent: Color(0xFFE89B74),
    danger: Color(0xFFF08A7E),
    success: Color(0xFF7CC4A0),
    field: Color(0xFF2C231E),
    fieldBorder: Color(0xFF4A3B32),
    placeholder: Color(0xFF33281F),
    shadow: Color(0x66000000),
    heroStart: Color(0xFF3A2B22),
    heroEnd: Color(0xFF2A201B),
  );

  @override
  PaperColors copyWith() => this;

  @override
  PaperColors lerp(PaperColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PaperColors(
      bg: l(bg, other.bg),
      card: l(card, other.card),
      border: l(border, other.border),
      chip: l(chip, other.chip),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      accent: l(accent, other.accent),
      danger: l(danger, other.danger),
      success: l(success, other.success),
      field: l(field, other.field),
      fieldBorder: l(fieldBorder, other.fieldBorder),
      placeholder: l(placeholder, other.placeholder),
      shadow: l(shadow, other.shadow),
      heroStart: l(heroStart, other.heroStart),
      heroEnd: l(heroEnd, other.heroEnd),
    );
  }
}

extension PaperContext on BuildContext {
  /// Falls back to the light palette when the theme has no [PaperColors]
  /// (e.g. a bare MaterialApp in tests).
  PaperColors get paper =>
      Theme.of(this).extension<PaperColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? PaperColors.dark
          : PaperColors.light);
}

/// App theme built on the paper palette, so Material defaults (dialogs,
/// sheets, snackbars, switches...) match the custom screens.
ThemeData paperTheme(Brightness brightness) {
  final p =
      brightness == Brightness.dark ? PaperColors.dark : PaperColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: paperAccentStrong,
    brightness: brightness,
  ).copyWith(
    primary: p.accent,
    surface: p.card,
    onSurface: p.ink,
    onSurfaceVariant: p.inkMuted,
    outlineVariant: p.border,
    error: p.danger,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
  );
}

/// Filled colours that keep white text readable (>= 5.5:1) in both modes.
const Color paperAccentStrong = Color(0xFF9E4A2C);
const Color paperSuccess = Color(0xFF2F6B4F);
const Color paperDanger = Color(0xFFB54132);

TextStyle paperTitle(BuildContext context,
        {double fontSize = 22, Color? color}) =>
    GoogleFonts.dmSerifDisplay(
      color: color ?? context.paper.ink,
      fontSize: fontSize,
      letterSpacing: 0.2,
    );

TextStyle paperValue(BuildContext context,
        {double fontSize = 15, Color? color}) =>
    GoogleFonts.karla(
      color: color ?? context.paper.ink,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    );

TextStyle paperMuted(BuildContext context,
        {double fontSize = 13, Color? color}) =>
    GoogleFonts.karla(
        color: color ?? context.paper.inkMuted, fontSize: fontSize);

TextStyle paperLabel(BuildContext context,
        {double fontSize = 11, Color? color}) =>
    GoogleFonts.karla(
      color: color ?? context.paper.inkMuted,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

BoxDecoration paperCardDecoration(BuildContext context,
        {Color? color, Color? border}) =>
    BoxDecoration(
      color: color ?? context.paper.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border ?? context.paper.border),
      boxShadow: [
        BoxShadow(
          color: context.paper.shadow,
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    );

InputDecoration paperInputDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  Widget? prefixIcon,
}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: paperMuted(context),
      hintStyle: paperMuted(context),
      prefixIcon: prefixIcon,
      prefixIconColor: context.paper.inkMuted,
      filled: true,
      fillColor: context.paper.field,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.paper.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.paper.accent, width: 1.5),
      ),
    );

AppBar paperAppBar(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) =>
    AppBar(
      backgroundColor: context.paper.bg,
      surfaceTintColor: context.paper.bg,
      elevation: 0,
      iconTheme: IconThemeData(color: context.paper.ink),
      actionsIconTheme: IconThemeData(color: context.paper.ink),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `header: true` lets screen readers jump straight to the screen name.
          Semantics(
            header: true,
            child: Text(title, style: paperTitle(context)),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: paperMuted(context, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: actions,
      bottom: bottom,
    );

TabBar paperTabBar(BuildContext context, List<Widget> tabs) => TabBar(
      tabs: tabs,
      labelColor: context.paper.ink,
      unselectedLabelColor: context.paper.inkMuted,
      indicatorColor: context.paper.accent,
      indicatorWeight: 3,
      dividerColor: Colors.transparent,
      labelStyle: paperValue(context, fontSize: 14),
      unselectedLabelStyle: paperMuted(context, fontSize: 14),
    );

/// Rounded square holding a leading icon, as used by the settings tiles.
class PaperIconChip extends StatelessWidget {
  const PaperIconChip({
    super.key,
    required this.icon,
    this.color,
    this.background,
    this.size = 20,
  });

  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background ?? context.paper.chip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color ?? context.paper.accent, size: size),
    );
  }
}

/// Empty/error placeholder. Scrollable on purpose so it can be wrapped in a
/// [RefreshIndicator] and still be pulled down.
class PaperEmptyState extends StatelessWidget {
  const PaperEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
      children: [
        Icon(icon,
            size: 56, color: context.paper.inkMuted.withValues(alpha: 0.75)),
        const SizedBox(height: 16),
        Text(
          title,
          style: paperValue(context, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            style: paperMuted(context, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 24),
          Center(child: action!),
        ],
      ],
    );
  }
}

/// Confirmation dialog shared by the friends/chat screens, so every
/// destructive prompt looks and reads the same way.
Future<bool> paperConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool danger = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.paper.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: paperTitle(context, fontSize: 21)),
      content: Text(message, style: paperMuted(context, fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: context.paper.ink),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: danger ? ctx.paper.danger : ctx.paper.accent,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Single-button informational dialog.
Future<void> paperInfo(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = 'OK',
  VoidCallback? onDismissed,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.paper.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: paperTitle(context, fontSize: 21)),
      content: Text(message, style: paperMuted(context, fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(foregroundColor: context.paper.ink),
          child: Text(okLabel),
        ),
      ],
    ),
  );
  onDismissed?.call();
}
