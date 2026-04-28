import 'dart:ui';
import 'package:flutter/material.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  SPATIAL GLASS DESIGN SYSTEM — Meta Horizon OS v60+ Language
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ── Colours ─────────────────────────────────────────────────────────────────

/// Meta blue primary accent.
const Color kMetaBlue = Color(0xFF0064E0);

/// Vibrant action-orange accent (use when brand calls for warmth).
const Color kActionOrange = Color(0xFFFF6B00);

// Dark-mode base surfaces – "void" behind the glass layers
const Color kVoidDark = Color(0xFF080C14);
const Color kVoidMid = Color(0xFF0D1420);

// Light-mode base surface
const Color kVoidLight = Color(0xFFEDF1F7);

// ── Opacity tokens ───────────────────────────────────────────────────────────

/// Base glass opacity – dark mode (content panels).
const double kGlassDark = 0.08;

/// Base glass opacity – light mode (content panels).
const double kGlassLight = 0.60;

/// Slightly deeper surface for "carved" inputs.
const double kInputGlassDark = 0.12;
const double kInputGlassLight = 0.72;

/// Top-left "light-catch" highlight opacity for inner borders.
const double kLightCatchBright = 0.20;
const double kLightCatchDim = 0.05;

// ── Geometry ─────────────────────────────────────────────────────────────────

/// Standard panel / card corner radius.
const double kRadius = 28.0;

/// Tighter radius used for inline chips only.
const double kRadiusSmall = 16.0;

/// Floating element margin from screen edge (detached HUDs).
const double kFloatMargin = 20.0;

/// Standard internal padding for glass panels.
const EdgeInsets kPanelPadding = EdgeInsets.all(20.0);

/// Glow blur radius for active-state elements.
const double kGlowBlur = 10.0;
const double kGlowSpread = 0.0;

// ── Blur radii ────────────────────────────────────────────────────────────────

const double kBlurBase = 40.0;
const double kBlurModal = 60.0;

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  HELPER FUNCTIONS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Returns the translucent fill colour for a glass surface.
Color glassColor(bool isDark) => isDark
    ? Colors.white.withValues(alpha: kGlassDark)
    : Colors.white.withValues(alpha: kGlassLight);

/// Deeper variant for carved inputs.
Color inputGlassColor(bool isDark) => isDark
    ? Colors.white.withValues(alpha: kInputGlassDark)
    : Colors.white.withValues(alpha: kInputGlassLight);

/// The 1-px "light catch" inner border gradient: brighter top-left,
/// dimmer bottom-right — simulating a virtual light source.
BoxDecoration glassDecoration({
  required bool isDark,
  double radius = kRadius,
  bool isInput = false,
  bool isActive = false,
  Color? activeColor,
  double? customOpacity,
}) {
  final bg = customOpacity != null
      ? Colors.white.withValues(alpha: customOpacity)
      : (isInput ? inputGlassColor(isDark) : glassColor(isDark));

  final borderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: kLightCatchBright),
      Colors.white.withValues(alpha: kLightCatchDim),
    ],
  );

  final List<BoxShadow> shadows = [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
      blurRadius: 24,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    ),
  ];

  if (isActive && activeColor != null) {
    shadows.add(
      BoxShadow(
        color: activeColor.withValues(alpha: 0.45),
        blurRadius: kGlowBlur,
        spreadRadius: kGlowSpread,
      ),
    );
  }

  return BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(radius),
    border: GradientBorder(gradient: borderGradient, width: 1.0),
    boxShadow: shadows,
  );
}

/// Convenience wrapper that applies glassDecoration + BackdropFilter blur.
/// Wrap any widget tree with this to get a "frosted glass" panel.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final double radius;
  final bool isInput;
  final bool isActive;
  final Color? activeColor;
  final EdgeInsets? padding;
  final double? customOpacity;
  final double blurSigma;

  const GlassPanel({
    super.key,
    required this.child,
    required this.isDark,
    this.radius = kRadius,
    this.isInput = false,
    this.isActive = false,
    this.activeColor,
    this.padding,
    this.customOpacity,
    this.blurSigma = kBlurBase,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: glassDecoration(
            isDark: isDark,
            radius: radius,
            isInput: isInput,
            isActive: isActive,
            activeColor: activeColor,
            customOpacity: customOpacity,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Pill-shaped glass container (Stadium/Capsule border).
class GlassCapsule extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final bool isActive;
  final Color? activeColor;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const GlassCapsule({
    super.key,
    required this.child,
    required this.isDark,
    this.isActive = false,
    this.activeColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = activeColor ?? kMetaBlue;

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutQuint,
          padding: padding,
          decoration: BoxDecoration(
            color: isActive
                ? accent.withValues(alpha: 0.85)
                : glassColor(isDark),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive
                  ? accent.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: kLightCatchBright),
              width: 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: kGlowBlur,
                      spreadRadius: kGlowSpread,
                    ),
                  ]
                : [],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

/// Spatial press-effect button: scales to 0.95x on press, loses shadow.
class SpatialButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isDark;
  final Color? accentColor;
  final bool isActive;
  final EdgeInsets padding;

  const SpatialButton({
    super.key,
    required this.child,
    this.onPressed,
    required this.isDark,
    this.accentColor,
    this.isActive = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  @override
  State<SpatialButton> createState() => _SpatialButtonState();
}

class _SpatialButtonState extends State<SpatialButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? kMetaBlue;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: _pressed ? 0.95 : 1.0),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutQuint,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutQuint,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.isActive
                    ? accent.withValues(alpha: _pressed ? 0.70 : 0.85)
                    : (
                        isDark: widget.isDark,
                        isInput: false,
                        customOpacity: null,
                      )._glassColorFor(),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: widget.isActive
                      ? accent.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: kLightCatchBright),
                  width: 1.0,
                ),
                boxShadow: _pressed
                    ? []
                    : widget.isActive
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.45),
                          blurRadius: kGlowBlur,
                          spreadRadius: kGlowSpread,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: widget.isDark ? 0.30 : 0.08,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

extension _GlassHelper on ({bool isDark, bool isInput, double? customOpacity}) {
  Color _glassColorFor() {
    if (customOpacity != null) {
      return Colors.white.withValues(alpha: customOpacity!);
    }
    return isInput ? inputGlassColor(isDark) : glassColor(isDark);
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  GRADIENT BORDER — paints a 1-px gradient stroke inside ClipRRect
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class GradientBorder extends BoxBorder {
  final Gradient gradient;
  final double width;

  const GradientBorder({required this.gradient, required this.width});

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  BorderSide get top => BorderSide.none;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  bool get isUniform => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    if (borderRadius != null) {
      canvas.drawRRect(borderRadius.toRRect(rect.deflate(width / 2)), paint);
    } else {
      canvas.drawRect(rect.deflate(width / 2), paint);
    }
  }

  @override
  ShapeBorder scale(double t) => this;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  SPATIAL THEME DATA
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ThemeData spatialDarkTheme(Color accent) => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kVoidDark,
  cardColor: Colors.transparent,
  colorScheme: ColorScheme.dark(
    primary: accent,
    secondary: accent,
    surface: kVoidMid,
    onSurface: Colors.white,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
  ),
  textTheme: _spatialTextTheme(Brightness.dark),
  inputDecorationTheme: _spatialInputTheme(isDark: true, accent: accent),
  switchTheme: SwitchThemeData(
    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return accent;
      return Colors.white.withValues(alpha: 0.12);
    }),
    thumbColor: WidgetStateProperty.all(Colors.white),
  ),
);

ThemeData spatialLightTheme(Color accent) => ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: kVoidLight,
  cardColor: Colors.transparent,
  colorScheme: ColorScheme.light(
    primary: accent,
    secondary: accent,
    surface: Colors.white.withValues(alpha: 0.70),
    onSurface: Colors.black87,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.black87,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
  ),
  textTheme: _spatialTextTheme(Brightness.light),
  inputDecorationTheme: _spatialInputTheme(isDark: false, accent: accent),
  switchTheme: SwitchThemeData(
    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return accent;
      return Colors.black.withValues(alpha: 0.12);
    }),
    thumbColor: WidgetStateProperty.all(Colors.white),
  ),
);

TextTheme _spatialTextTheme(Brightness brightness) {
  final base = brightness == Brightness.dark ? Colors.white : Colors.black87;
  final secondary = brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.65)
      : Colors.black.withValues(alpha: 0.65);
  return TextTheme(
    displayLarge: TextStyle(
      color: base,
      fontWeight: FontWeight.w700,
      fontSize: 32,
      letterSpacing: -0.5,
    ),
    displayMedium: TextStyle(
      color: base,
      fontWeight: FontWeight.w700,
      fontSize: 26,
    ),
    headlineMedium: TextStyle(
      color: base,
      fontWeight: FontWeight.w600,
      fontSize: 20,
    ),
    titleMedium: TextStyle(
      color: base,
      fontWeight: FontWeight.w600,
      fontSize: 16,
    ),
    bodyMedium: TextStyle(color: base, fontSize: 14),
    bodySmall: TextStyle(color: secondary, fontSize: 12),
    labelSmall: TextStyle(color: secondary, fontSize: 11),
  );
}

InputDecorationTheme _spatialInputTheme({
  required bool isDark,
  required Color accent,
}) => InputDecorationTheme(
  filled: true,
  fillColor: inputGlassColor(isDark),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(999),
    borderSide: BorderSide(
      color: Colors.white.withValues(alpha: kLightCatchBright),
      width: 1.0,
    ),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(999),
    borderSide: BorderSide(
      color: Colors.white.withValues(alpha: kLightCatchBright),
      width: 1.0,
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(999),
    borderSide: BorderSide(color: accent.withValues(alpha: 0.80), width: 1.5),
  ),
  hintStyle: TextStyle(
    color: isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.38),
    fontSize: 14,
  ),
);
