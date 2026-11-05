import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Sticker Pop" art direction: flat pop colours, thick ink outlines and hard
/// offset shadows, set in Bricolage Grotesque.
///
/// Every colour used on text or icons is checked against its background for
/// a WCAG AA contrast ratio (4.5:1 for body text, 3:1 for large text/icons):
/// white only ever sits on [popPurple] or [popInk], every other pop colour
/// carries ink text.
const Color popYellow = Color(0xFFFFD23F); // « Défi »
const Color popPurple = Color(0xFF6D3FE0); // « Groupe »
const Color popCoral = Color(0xFFFF6B57); // « Réaction »
const Color popGreen = Color(0xFF3DDC97); // « Validé »
const Color popBg = Color(0xFFE9E1FF); // « Fond »
const Color popInk = Color(0xFF111111); // « Contour »

const Color popCard = Colors.white;
const Color popInkMuted = Color(0xFF5A5468);

/// Placeholder behind photos that are still loading.
const Color popPhoto = Color(0xFFB7A6F5);

/// Error text and icons on light surfaces. Destructive buttons use
/// [popCoral] with ink text instead.
const Color popDanger = Color(0xFFB42F1C);

const double popStroke = 2.5;

List<BoxShadow> popShadow([double offset = 5]) => [
      BoxShadow(color: popInk, offset: Offset(offset, offset)),
    ];

TextStyle popDisplay({double fontSize = 28, Color color = popInk}) =>
    GoogleFonts.bricolageGrotesque(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.08,
      letterSpacing: -0.6,
    );

TextStyle popTitle({double fontSize = 22, Color color = popInk}) =>
    GoogleFonts.bricolageGrotesque(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    );

TextStyle popValue({double fontSize = 15, Color color = popInk}) =>
    GoogleFonts.bricolageGrotesque(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
    );

TextStyle popBody({double fontSize = 15, Color color = popInk}) =>
    GoogleFonts.bricolageGrotesque(
      color: color,
      fontSize: fontSize,
      height: 1.35,
    );

TextStyle popMuted({double fontSize = 13, Color color = popInkMuted}) =>
    GoogleFonts.bricolageGrotesque(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    );

/// Small caps-style labels (« DÉFI DE LA SEMAINE »): pass upper-case text.
TextStyle popLabel({double fontSize = 12, Color color = popInk}) =>
    GoogleFonts.bricolageGrotesque(
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
    );

BoxDecoration popCardDecoration({
  Color color = popCard,
  double radius = 22,
  double shadow = 5,
}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: popInk, width: popStroke),
      boxShadow: shadow > 0 ? popShadow(shadow) : null,
    );

/// App-wide theme, so plain Material widgets (fields, dialogs, pickers,
/// snack bars…) come out in the Sticker Pop style without per-call styling.
ThemeData buildStickerPopTheme() {
  const inkSide = BorderSide(color: popInk, width: popStroke);
  final rounded = BorderRadius.circular(14);
  final textTheme = GoogleFonts.bricolageGrotesqueTextTheme()
      .apply(bodyColor: popInk, displayColor: popInk);

  OutlineInputBorder fieldBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: rounded,
        borderSide: BorderSide(color: color, width: width),
      );

  final buttonShape = RoundedRectangleBorder(borderRadius: rounded);
  const buttonSize = Size(0, 48);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 12);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: popPurple,
      primary: popPurple,
      onPrimary: Colors.white,
      secondary: popYellow,
      onSecondary: popInk,
      tertiary: popGreen,
      onTertiary: popInk,
      error: popDanger,
      onError: Colors.white,
      surface: popCard,
      onSurface: popInk,
      onSurfaceVariant: popInkMuted,
      outline: popInk,
      outlineVariant: const Color(0xFFCFC3F5),
      surfaceTint: Colors.transparent,
    ),
    scaffoldBackgroundColor: popBg,
    canvasColor: popCard,
    textTheme: textTheme,
    iconTheme: const IconThemeData(color: popInk),
    appBarTheme: AppBarTheme(
      backgroundColor: popBg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: popInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: popTitle(),
      iconTheme: const IconThemeData(color: popInk),
      systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: popPurple,
        foregroundColor: Colors.white,
        disabledBackgroundColor: popBg,
        disabledForegroundColor: popInkMuted,
        side: inkSide,
        shape: buttonShape,
        minimumSize: buttonSize,
        padding: buttonPadding,
        textStyle: popValue(),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: popPurple,
        foregroundColor: Colors.white,
        disabledBackgroundColor: popBg,
        disabledForegroundColor: popInkMuted,
        elevation: 0,
        side: inkSide,
        shape: buttonShape,
        minimumSize: buttonSize,
        padding: buttonPadding,
        textStyle: popValue(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: popInk,
        backgroundColor: popCard,
        side: inkSide,
        shape: buttonShape,
        minimumSize: buttonSize,
        padding: buttonPadding,
        textStyle: popValue(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: popPurple,
        textStyle: popValue(),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: popPurple,
      foregroundColor: Colors.white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: inkSide,
      ),
      extendedTextStyle: popValue(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: popCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: popMuted(fontSize: 15),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        if (states.contains(WidgetState.error)) {
          return popValue(fontSize: 15, color: popDanger);
        }
        if (states.contains(WidgetState.focused)) {
          return popValue(fontSize: 15, color: popPurple);
        }
        return popValue(fontSize: 15, color: popInkMuted);
      }),
      hintStyle: popMuted(fontSize: 15),
      helperStyle: popMuted(fontSize: 12),
      errorStyle: popValue(fontSize: 12, color: popDanger),
      prefixIconColor: popInkMuted,
      border: fieldBorder(popInk, 2),
      enabledBorder: fieldBorder(popInk, 2),
      focusedBorder: fieldBorder(popPurple, popStroke),
      errorBorder: fieldBorder(popDanger, 2),
      focusedErrorBorder: fieldBorder(popDanger, popStroke),
      disabledBorder: fieldBorder(popInkMuted, 2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: popCard,
      contentTextStyle: popValue(fontSize: 14),
      actionTextColor: popPurple,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: rounded, side: inkSide),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: popCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: inkSide,
      ),
      titleTextStyle: popTitle(fontSize: 21),
      contentTextStyle: popBody(),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: popCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      dragHandleColor: popInk,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        side: inkSide,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: popCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: rounded, side: inkSide),
      textStyle: popValue(fontSize: 14),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: popCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      headerBackgroundColor: popYellow,
      headerForegroundColor: popInk,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: inkSide,
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: popCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: inkSide,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return popInkMuted;
        return states.contains(WidgetState.selected) ? Colors.white : popInk;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return popBg;
        return states.contains(WidgetState.selected) ? popPurple : popCard;
      }),
      trackOutlineColor: const WidgetStatePropertyAll(popInk),
      trackOutlineWidth: const WidgetStatePropertyAll(2),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? popPurple
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: const BorderSide(color: popInk, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: popPurple,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: popInk,
      unselectedLabelColor: popInkMuted,
      labelStyle: popValue(fontSize: 14),
      unselectedLabelStyle: popValue(fontSize: 14),
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: popYellow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: popInk, width: 2),
      ),
      dividerColor: Colors.transparent,
      splashBorderRadius: BorderRadius.circular(12),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: popInk,
      titleTextStyle: popValue(),
      subtitleTextStyle: popMuted(),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: popPurple,
      selectionColor: popPurple.withValues(alpha: 0.3),
      selectionHandleColor: popPurple,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: popInk,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: popValue(fontSize: 12, color: Colors.white),
    ),
  );
}

AppBar popAppBar({
  required String title,
  String? subtitle,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) =>
    AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `header: true` lets screen readers jump straight to the screen name.
          Semantics(
            header: true,
            child: Text(title, style: popTitle()),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: popMuted(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: actions,
      bottom: bottom,
    );

/// Tabs whose selection is a yellow sticker (style comes from the theme).
TabBar popTabBar(List<Widget> tabs) => TabBar(
      tabs: tabs,
      indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    );

/// Shared tap behaviour of every sticker control: the hard shadow collapses
/// and the sticker sinks into it while pressed.
class PopPressable extends StatefulWidget {
  const PopPressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.color = popCard,
    this.radius = 14,
    this.shadow = 4,
    this.selected,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final double radius;
  final double shadow;

  /// Announced to screen readers for toggles (chips, tabs).
  final bool? selected;

  /// Needed when [child] has no text of its own (icon-only buttons).
  final String? semanticLabel;

  @override
  State<PopPressable> createState() => _PopPressableState();
}

class _PopPressableState extends State<PopPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final sink = _pressed ? widget.shadow : 0.0;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          transform: Matrix4.translationValues(sink, sink, 0),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: popInk, width: popStroke),
            boxShadow: _pressed || !enabled || widget.shadow == 0
                ? null
                : popShadow(widget.shadow),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              borderRadius: BorderRadius.circular(widget.radius),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Labelled sticker button (« Je le fais ! », « Principal », « Upvoté »…).
class PopButton extends StatelessWidget {
  const PopButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = popPurple,
    this.foreground = Colors.white,
    this.expand = false,
    this.loading = false,
    this.dense = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color foreground;
  final bool expand;

  /// Shows a spinner and ignores taps without looking disabled.
  final bool loading;
  final bool dense;

  /// Replaces [label] for screen readers when the visible text is terse.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final leading = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child:
                CircularProgressIndicator(strokeWidth: 2.5, color: foreground),
          )
        : icon == null
            ? null
            : Icon(icon, size: dense ? 18 : 20, color: foreground);

    final button = PopPressable(
      onPressed: onPressed == null ? null : (loading ? () {} : onPressed),
      color: color,
      // An ink shadow under an ink button only reads as a thicker edge.
      shadow: color == popInk ? 0 : (dense ? 3 : 4),
      semanticLabel: semanticLabel,
      child: ConstrainedBox(
        // 44/48 px: minimum recommended touch targets.
        constraints: BoxConstraints(minHeight: dense ? 44 : 48),
        child: ExcludeSemantics(
          excluding: semanticLabel != null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 20),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[leading, const SizedBox(width: 8)],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: popValue(
                      fontSize: dense ? 14 : 16,
                      color: foreground,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Square sticker button holding a single icon. [tooltip] doubles as the
/// screen-reader label.
class PopIconButton extends StatelessWidget {
  const PopIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = popCard,
    this.foreground = popInk,
    this.size = 48,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  final Color foreground;
  final double size;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: PopPressable(
        onPressed: onPressed == null ? null : (busy ? () {} : onPressed),
        semanticLabel: tooltip,
        color: color,
        radius: size * 0.32,
        shadow: 3,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: busy
                ? SizedBox(
                    width: size * 0.4,
                    height: size * 0.4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: foreground,
                    ),
                  )
                : Icon(icon, color: foreground, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}

/// Filter chip: purple and lifted when selected, flat white otherwise.
class PopChip extends StatelessWidget {
  const PopChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Replaces [label] for screen readers when the icon carries meaning.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : popInk;

    return PopPressable(
      onPressed: onTap,
      selected: selected,
      semanticLabel: semanticLabel,
      color: selected ? popPurple : popCard,
      radius: 999,
      shadow: selected ? 3 : 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, maxWidth: 240),
        child: ExcludeSemantics(
          excluding: semanticLabel != null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: popValue(fontSize: 14, color: foreground)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tilted tag stuck on cards and photos (« Défi validé », countdowns…).
class PopSticker extends StatelessWidget {
  const PopSticker({
    super.key,
    required this.label,
    this.color = popYellow,
    this.icon,
    this.angle = -0.05,
    this.fontSize = 13,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final double angle;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: popInk, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: fontSize + 2, color: popInk),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: popValue(fontSize: fontSize)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Crazy | Real » wordmark made of two tilted stickers.
class PopLogo extends StatelessWidget {
  const PopLogo({super.key, this.fontSize = 24});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    Widget word(String text, Color color, double angle) => Transform.rotate(
          angle: angle,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: fontSize * 0.4,
              vertical: fontSize * 0.08,
            ),
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: popInk, width: popStroke),
              boxShadow: popShadow(3),
            ),
            child: Text(
              text,
              style: popTitle(fontSize: fontSize).copyWith(letterSpacing: -0.8),
            ),
          ),
        );

    return Semantics(
      label: 'CrazyReal',
      header: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          word('Crazy', popYellow, -0.05),
          SizedBox(width: fontSize * 0.25),
          word('Real', popCard, 0.03),
        ],
      ),
    );
  }
}

/// Rounded square holding a leading icon, as used by the settings tiles.
class PopIconChip extends StatelessWidget {
  const PopIconChip({
    super.key,
    required this.icon,
    this.color = popInk,
    this.background = popBg,
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
        border: Border.all(color: popInk, width: 2),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

enum PopMascotMood { hello, confused, crying, happy }

/// The CrazyReal bunny as a die-cut sticker. Purely decorative: the text next
/// to it always carries the message.
class PopMascot extends StatelessWidget {
  const PopMascot(this.mood, {super.key, this.size = 150});

  final PopMascotMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/mascots/${mood.name}.png',
      width: size,
      height: size,
      // Decode at display size rather than the full 600 px source.
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      excludeFromSemantics: true,
    );
  }
}

/// Empty/error placeholder. Scrollable by default so it can be wrapped in a
/// [RefreshIndicator] and still be pulled down; pass `scrollable: false` to
/// drop it inside a page that already scrolls.
class PopEmptyState extends StatelessWidget {
  const PopEmptyState({
    super.key,
    required this.title,
    this.icon,
    this.mascot,
    this.message,
    this.action,
    this.scrollable = true,
  }) : assert(icon != null || mascot != null);

  final String title;
  final IconData? icon;
  final PopMascotMood? mascot;
  final String? message;
  final Widget? action;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(32, mascot != null ? 40 : 72, 32, 32);
    final children = [
      Center(
        child: mascot != null
            ? PopMascot(mascot!, size: 168)
            : Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: popCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: popInk, width: popStroke),
                  boxShadow: popShadow(4),
                ),
                child: Icon(icon, size: 38, color: popInk),
              ),
      ),
      const SizedBox(height: 20),
      Text(
        title,
        style: popTitle(fontSize: 20),
        textAlign: TextAlign.center,
      ),
      if (message != null) ...[
        const SizedBox(height: 8),
        Text(
          message!,
          style: popMuted(fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ],
      if (action != null) ...[
        const SizedBox(height: 24),
        Center(child: action!),
      ],
    ];

    if (!scrollable) {
      return Padding(
        padding: padding,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: children,
    );
  }
}

/// One entry of [PopNavBar].
class PopNavItem {
  const PopNavItem({
    required this.icon,
    required this.label,
    this.primary = false,
  });

  final IconData icon;
  final String label;

  /// The raised purple button in the middle (camera).
  final bool primary;
}

/// Floating bottom bar: the current tab sits on a yellow sticker, the primary
/// action is a tilted purple one. Labels are announced and shown as tooltips.
class PopNavBar extends StatelessWidget {
  const PopNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<PopNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Container(
          height: 72,
          decoration: popCardDecoration(radius: 26),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Center(
                    child: _PopNavButton(
                      item: items[i],
                      selected: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopNavButton extends StatelessWidget {
  const _PopNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PopNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (item.primary) {
      // Raised above the bar and tilted like a sticker; looks pressed while
      // its tab is open.
      return Transform.translate(
        offset: const Offset(0, -10),
        child: Transform.rotate(
          angle: -0.06,
          child: Tooltip(
            message: item.label,
            excludeFromSemantics: true,
            child: PopPressable(
              onPressed: onTap,
              selected: selected,
              semanticLabel: item.label,
              color: popPurple,
              radius: 18,
              shadow: selected ? 0 : 4,
              child: SizedBox.square(
                dimension: 60,
                child: Icon(item.icon, color: Colors.white, size: 30),
              ),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: item.label,
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        button: true,
        selected: selected,
        label: item.label,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: selected ? popYellow : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? popInk : Colors.transparent,
                  width: popStroke,
                ),
              ),
              child: Icon(item.icon, color: popInk, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirmation dialog shared by the friends/chat screens, so every
/// destructive prompt looks and reads the same way.
Future<bool> popConfirm(
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
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      actions: [
        PopButton(
          label: cancelLabel,
          dense: true,
          color: popCard,
          foreground: popInk,
          onPressed: () => Navigator.pop(ctx, false),
        ),
        PopButton(
          label: confirmLabel,
          dense: true,
          color: danger ? popCoral : popPurple,
          foreground: danger ? popInk : Colors.white,
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Single-button informational dialog.
Future<void> popInfo(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = 'OK',
  VoidCallback? onDismissed,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      actions: [
        PopButton(
          label: okLabel,
          dense: true,
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
  onDismissed?.call();
}
