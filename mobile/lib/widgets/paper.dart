import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared "warm paper" design tokens, extracted from the profile/settings
/// pages so the friends and chat screens stop re-inventing them.
///
/// Every colour used on text or icons is checked against its background for
/// a WCAG AA contrast ratio (4.5:1 for body text, 3:1 for large text/icons).
const Color paperBg = Color(0xFFF7EBD1);
const Color paperCard = Color(0xFFFFF7E6);
const Color paperBorder = Color(0xFFF0DFC2);
const Color paperChip = Color(0xFFF0DFC2);
const Color paperInk = Color(0xFF3B2A21);
const Color paperInkMuted = Color(0xFF6A4A3B);
const Color paperAccent = Color(0xFFB85C38);

/// Darker accent shades, used whenever white text or icons sit on top of the
/// colour (the light accent only reaches 4.5:1, these clear 5.5:1).
const Color paperAccentStrong = Color(0xFF9E4A2C);
const Color paperSuccess = Color(0xFF2F6B4F);
const Color paperDanger = Color(0xFFB54132);

TextStyle paperTitle({double fontSize = 22, Color color = paperInk}) =>
    GoogleFonts.dmSerifDisplay(
      color: color,
      fontSize: fontSize,
      letterSpacing: 0.2,
    );

TextStyle paperValue({double fontSize = 15, Color color = paperInk}) =>
    GoogleFonts.karla(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    );

TextStyle paperMuted({double fontSize = 13, Color color = paperInkMuted}) =>
    GoogleFonts.karla(color: color, fontSize: fontSize);

TextStyle paperLabel({double fontSize = 11, Color color = paperInkMuted}) =>
    GoogleFonts.karla(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

BoxDecoration paperCardDecoration({Color color = paperCard, Color? border}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border ?? paperBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F2E1B0F),
          blurRadius: 18,
          offset: Offset(0, 10),
        ),
      ],
    );

InputDecoration paperInputDecoration({
  String? label,
  String? hint,
  Widget? prefixIcon,
}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: paperMuted(),
      hintStyle: paperMuted(),
      prefixIcon: prefixIcon,
      prefixIconColor: paperInkMuted,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE7D3B5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: paperAccent, width: 1.5),
      ),
    );

AppBar paperAppBar({
  required String title,
  String? subtitle,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) =>
    AppBar(
      backgroundColor: paperBg,
      surfaceTintColor: paperBg,
      elevation: 0,
      iconTheme: const IconThemeData(color: paperInk),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `header: true` lets screen readers jump straight to the screen name.
          Semantics(
            header: true,
            child: Text(title, style: paperTitle()),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: paperMuted(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: actions,
      bottom: bottom,
    );

TabBar paperTabBar(List<Widget> tabs) => TabBar(
      tabs: tabs,
      labelColor: paperInk,
      unselectedLabelColor: paperInkMuted,
      indicatorColor: paperAccent,
      indicatorWeight: 3,
      dividerColor: Colors.transparent,
      labelStyle: paperValue(fontSize: 14),
      unselectedLabelStyle: paperMuted(fontSize: 14),
    );

/// Rounded square holding a leading icon, as used by the settings tiles.
class PaperIconChip extends StatelessWidget {
  const PaperIconChip({
    super.key,
    required this.icon,
    this.color = paperAccent,
    this.background = paperChip,
    this.size = 20,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: size),
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
        Icon(icon, size: 56, color: paperInkMuted.withValues(alpha: 0.75)),
        const SizedBox(height: 16),
        Text(
          title,
          style: paperValue(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            style: paperMuted(fontSize: 14),
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
      backgroundColor: paperCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: paperTitle(fontSize: 21)),
      content: Text(message, style: paperMuted(fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: paperInk),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: danger ? paperDanger : paperAccentStrong,
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
      backgroundColor: paperCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: paperTitle(fontSize: 21)),
      content: Text(message, style: paperMuted(fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(foregroundColor: paperInk),
          child: Text(okLabel),
        ),
      ],
    ),
  );
  onDismissed?.call();
}
