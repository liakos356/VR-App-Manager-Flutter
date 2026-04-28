import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/google_drive_service.dart';
import '../utils/localization.dart';
import '../utils/spatial_theme.dart';

/// A collapsible settings panel that slides in from the right edge.
/// When [isOpen] is true it expands to 320 px; when collapsed it shrinks to
/// a 52 px icon strip. Width is animated; [onToggle] flips the open state.
class SettingsSidePanel extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  // ── Filter state ───────────────────────────────────────────────────────────
  final bool ovrportFilter;
  final ValueChanged<bool> onOvrportFilterChanged;
  final bool availableOnly;
  final ValueChanged<bool> onAvailableOnlyChanged;
  final bool updatedRecentlyFilter;
  final ValueChanged<bool> onUpdatedRecentlyFilterChanged;
  final int updatedRecentlyDays;
  final ValueChanged<int> onUpdatedRecentlyDaysChanged;

  // ── Actions ────────────────────────────────────────────────────────────────
  final VoidCallback onReloadDatabase;
  final VoidCallback onOpenInstalledApps;
  final VoidCallback onOpenAppUpdater;

  const SettingsSidePanel({
    super.key,
    required this.isOpen,
    required this.onToggle,
    required this.ovrportFilter,
    required this.onOvrportFilterChanged,
    required this.availableOnly,
    required this.onAvailableOnlyChanged,
    required this.updatedRecentlyFilter,
    required this.onUpdatedRecentlyFilterChanged,
    required this.updatedRecentlyDays,
    required this.onUpdatedRecentlyDaysChanged,
    required this.onReloadDatabase,
    required this.onOpenInstalledApps,
    required this.onOpenAppUpdater,
  });

  // ── Palette helpers ────────────────────────────────────────────────────────

  Color _mutedText(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.45)
      : Colors.black.withValues(alpha: 0.38);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutQuint,
      width: isOpen ? 320 : 0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        border: isOpen
            ? Border(
                left: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1,
                ),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 32,
            offset: const Offset(-8, 0),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: kBlurBase, sigmaY: kBlurBase),
          child: ColoredBox(
            color: glassColor(isDark),
            child: isOpen
                ? _OpenPanel(
                    isOpen: isOpen,
                    onToggle: onToggle,
                    ovrportFilter: ovrportFilter,
                    onOvrportFilterChanged: onOvrportFilterChanged,
                    availableOnly: availableOnly,
                    onAvailableOnlyChanged: onAvailableOnlyChanged,
                    updatedRecentlyFilter: updatedRecentlyFilter,
                    onUpdatedRecentlyFilterChanged:
                        onUpdatedRecentlyFilterChanged,
                    updatedRecentlyDays: updatedRecentlyDays,
                    onUpdatedRecentlyDaysChanged: onUpdatedRecentlyDaysChanged,
                    onReloadDatabase: onReloadDatabase,
                    onOpenInstalledApps: onOpenInstalledApps,
                    onOpenAppUpdater: onOpenAppUpdater,
                  )
                : _CollapsedStrip(
                    onToggle: onToggle,
                    mutedText: _mutedText(isDark),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Collapsed strip ────────────────────────────────────────────────────────────

class _CollapsedStrip extends StatelessWidget {
  final VoidCallback onToggle;
  final Color mutedText;

  const _CollapsedStrip({required this.onToggle, required this.mutedText});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Tooltip(
          message: 'Open Settings',
          child: IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: onToggle,
          ),
        ),
        const SizedBox(height: 6),
        Icon(Icons.tune, size: 20, color: mutedText),
      ],
    );
  }
}

// ── Open panel ─────────────────────────────────────────────────────────────────

class _OpenPanel extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onToggle;
  final bool ovrportFilter;
  final ValueChanged<bool> onOvrportFilterChanged;
  final bool availableOnly;
  final ValueChanged<bool> onAvailableOnlyChanged;
  final bool updatedRecentlyFilter;
  final ValueChanged<bool> onUpdatedRecentlyFilterChanged;
  final int updatedRecentlyDays;
  final ValueChanged<int> onUpdatedRecentlyDaysChanged;
  final VoidCallback onReloadDatabase;
  final VoidCallback onOpenInstalledApps;
  final VoidCallback onOpenAppUpdater;

  const _OpenPanel({
    required this.isOpen,
    required this.onToggle,
    required this.ovrportFilter,
    required this.onOvrportFilterChanged,
    required this.availableOnly,
    required this.onAvailableOnlyChanged,
    required this.updatedRecentlyFilter,
    required this.onUpdatedRecentlyFilterChanged,
    required this.updatedRecentlyDays,
    required this.onUpdatedRecentlyDaysChanged,
    required this.onReloadDatabase,
    required this.onOpenInstalledApps,
    required this.onOpenAppUpdater,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.40)
        : Colors.black.withValues(alpha: 0.35);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: onToggle,
                tooltip: 'Close Settings',
              ),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),

        // ── Scrollable body ─────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Display ─────────────────────────────────────────────
                _SectionLabel(label: 'Display', accent: accent),

                ValueListenableBuilder<bool>(
                  valueListenable: isGreekNotifier,
                  builder: (context, isGreek, _) => _GlassTile(
                    icon: Icons.language_outlined,
                    title: 'Language',
                    isDark: isDark,
                    trailing: _PillTag(
                      label: isGreek ? 'GR' : 'EN',
                      accent: accent,
                    ),
                    onTap: () async {
                      isGreekNotifier.value = !isGreekNotifier.value;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isGreek', isGreekNotifier.value);
                    },
                  ),
                ),

                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, mode, _) {
                    final dark = mode == ThemeMode.dark;
                    return _GlassTile(
                      icon: dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      title: 'Theme',
                      isDark: isDark,
                      trailing: _PillTag(
                        label: dark ? 'Dark' : 'Light',
                        accent: accent,
                      ),
                      onTap: () async {
                        final newMode =
                            dark ? ThemeMode.light : ThemeMode.dark;
                        themeNotifier.value = newMode;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(
                          'themeMode',
                          newMode == ThemeMode.dark ? 'dark' : 'light',
                        );
                      },
                    );
                  },
                ),

                // Accent Color
                ValueListenableBuilder<int>(
                  valueListenable: accentIndexNotifier,
                  builder: (context, accentIdx, _) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        decoration: BoxDecoration(
                          color: inputGlassColor(isDark),
                          borderRadius:
                              BorderRadius.circular(kRadiusSmall),
                          border: Border.all(
                            color: Colors.white
                                .withValues(alpha: isDark ? 0.08 : 0.25),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.palette_outlined,
                                  size: 15,
                                  color: mutedColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Accent Color',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(
                                accentColorOptions.length,
                                (i) {
                                  final opt = accentColorOptions[i];
                                  final color = isDark
                                      ? opt.darkColor
                                      : opt.lightColor;
                                  final selected = i == accentIdx;
                                  return Tooltip(
                                    message: opt.name,
                                    child: GestureDetector(
                                      onTap: () async {
                                        accentIndexNotifier.value = i;
                                        final prefs = await SharedPreferences
                                            .getInstance();
                                        await prefs.setInt(
                                          'accentColorIndex',
                                          i,
                                        );
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selected
                                                ? Colors.white
                                                : Colors.transparent,
                                            width: 2.5,
                                          ),
                                          boxShadow: selected
                                              ? [
                                                  BoxShadow(
                                                    color: color.withValues(
                                                      alpha: 0.55,
                                                    ),
                                                    blurRadius: 6,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: selected
                                            ? const Icon(
                                                Icons.check,
                                                size: 13,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // UI Scale
                ValueListenableBuilder<double>(
                  valueListenable: uiScaleNotifier,
                  builder: (context, scale, _) => _GlassSliderTile(
                    icon: Icons.zoom_in_outlined,
                    title: 'UI Scale',
                    value: scale,
                    min: 0.7,
                    max: 1.5,
                    divisions: 16,
                    valueLabel: '${(scale * 100).round()}%',
                    onChanged: (v) async {
                      uiScaleNotifier.value = v;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('uiScale', v);
                    },
                    isDark: isDark,
                    accent: accent,
                  ),
                ),

                // ── Filters ─────────────────────────────────────────────
                _SectionLabel(label: 'Filters', accent: accent),

                _GlassSwitchTile(
                  icon: Icons.vrpano_outlined,
                  title: 'Ovrport Only',
                  subtitle: 'Compatible apps only',
                  value: ovrportFilter,
                  onChanged: onOvrportFilterChanged,
                  isDark: isDark,
                  accent: accent,
                ),
                _GlassSwitchTile(
                  icon: Icons.cloud_download_outlined,
                  title: 'Available Only',
                  subtitle: 'Hide apps not on server',
                  value: availableOnly,
                  onChanged: onAvailableOnlyChanged,
                  isDark: isDark,
                  accent: accent,
                ),
                _GlassSwitchTile(
                  icon: Icons.new_releases_outlined,
                  title: 'Updated Recently',
                  subtitle:
                      'Last $updatedRecentlyDays day${updatedRecentlyDays == 1 ? '' : 's'}',
                  value: updatedRecentlyFilter,
                  onChanged: onUpdatedRecentlyFilterChanged,
                  isDark: isDark,
                  accent: accent,
                ),
                if (updatedRecentlyFilter)
                  _GlassSliderTile(
                    icon: Icons.calendar_today_outlined,
                    title: 'Days window',
                    value: updatedRecentlyDays.toDouble(),
                    min: 1,
                    max: 90,
                    divisions: 89,
                    valueLabel: '$updatedRecentlyDays d',
                    onChanged: (v) => onUpdatedRecentlyDaysChanged(v.round()),
                    isDark: isDark,
                    accent: accent,
                  ),

                // ── Actions ─────────────────────────────────────────────
                _SectionLabel(label: 'Actions', accent: accent),

                _GlassPillAction(
                  icon: Icons.sync_rounded,
                  title: 'Reload Database',
                  onTap: onReloadDatabase,
                  isDark: isDark,
                  accent: accent,
                ),
                const SizedBox(height: 6),
                _GlassPillAction(
                  icon: Icons.install_mobile_rounded,
                  title: 'Installed Apps',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: onOpenInstalledApps,
                  isDark: isDark,
                  accent: accent,
                ),
                const SizedBox(height: 6),
                _GlassPillAction(
                  icon: Icons.system_update_alt_outlined,
                  title: 'App Updater',
                  subtitle: 'Browse & install from Drive',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  onTap: onOpenAppUpdater,
                  isDark: isDark,
                  accent: accent,
                ),

                // ── Account ─────────────────────────────────────────────
                _SectionLabel(label: 'Account', accent: accent),

                ValueListenableBuilder<GoogleUserInfo?>(
                  valueListenable: GoogleDriveService().userNotifier,
                  builder: (ctx, user, _) => _GoogleDriveCard(
                    user: user,
                    isDark: isDark,
                    accent: accent,
                    onSignOut: () => GoogleDriveService().signOut(),
                    onSignIn: () async {
                      try {
                        await GoogleDriveService().startOAuthFlow(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Google sign-in failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),

                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'VR App Manager',
                    style: TextStyle(fontSize: 10, color: mutedColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color accent;
  const _SectionLabel({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: accent.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class _PillTag extends StatelessWidget {
  final String label;
  final Color accent;
  const _PillTag({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.30), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}

class _GlassTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDark;

  const _GlassTile({
    required this.icon,
    required this.title,
    required this.isDark,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusSmall),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: inputGlassColor(isDark),
              borderRadius: BorderRadius.circular(kRadiusSmall),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.22),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.50)
                      : Colors.black.withValues(alpha: 0.42),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  final Color accent;

  const _GlassSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.isDark,
    required this.accent,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: inputGlassColor(isDark),
          borderRadius: BorderRadius.circular(kRadiusSmall),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.22),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: value
                  ? accent
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.black.withValues(alpha: 0.38)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13)),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.40)
                            : Colors.black.withValues(alpha: 0.35),
                      ),
                    ),
                ],
              ),
            ),
            Transform.scale(
              scale: 0.80,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: accent,
                activeTrackColor: accent.withValues(alpha: 0.35),
                inactiveThumbColor: isDark
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.25),
                inactiveTrackColor: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassSliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;
  final bool isDark;
  final Color accent;

  const _GlassSliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
    required this.isDark,
    required this.accent,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        decoration: BoxDecoration(
          color: inputGlassColor(isDark),
          borderRadius: BorderRadius.circular(kRadiusSmall),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.22),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.40)
                      : Colors.black.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 12)),
                ),
                Text(
                  valueLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 5,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 10,
                ),
                activeTrackColor: accent.withValues(alpha: 0.75),
                inactiveTrackColor: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.12),
                thumbColor: accent,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPillAction extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isDark;
  final Color accent;

  const _GlassPillAction({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.isDark,
    required this.accent,
    this.subtitle,
    this.trailing,
  });

  @override
  State<_GlassPillAction> createState() => _GlassPillActionState();
}

class _GlassPillActionState extends State<_GlassPillAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.accent.withValues(alpha: 0.15)
              : inputGlassColor(widget.isDark),
          borderRadius: BorderRadius.circular(kRadiusSmall),
          border: Border.all(
            color: _pressed
                ? widget.accent.withValues(alpha: 0.40)
                : Colors.white.withValues(
                    alpha: widget.isDark ? 0.08 : 0.22,
                  ),
            width: 1,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.15),
                    blurRadius: kGlowBlur,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 16,
              color: widget.accent.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.40)
                            : Colors.black.withValues(alpha: 0.38),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}

class _GoogleDriveCard extends StatelessWidget {
  final GoogleUserInfo? user;
  final bool isDark;
  final Color accent;
  final VoidCallback onSignOut;
  final VoidCallback onSignIn;

  const _GoogleDriveCard({
    required this.user,
    required this.isDark,
    required this.accent,
    required this.onSignOut,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: user == null ? onSignIn : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: inputGlassColor(isDark),
          borderRadius: BorderRadius.circular(kRadiusSmall),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: accent.withValues(alpha: 0.15),
              backgroundImage: user?.photoUrl != null
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: user?.photoUrl == null
                  ? Icon(
                      Icons.account_circle_outlined,
                      size: 22,
                      color: isDark ? Colors.white54 : Colors.black45,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Google Drive',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    user?.email ?? 'Tap to sign in',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.45)
                          : Colors.black.withValues(alpha: 0.45),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (user != null)
              GestureDetector(
                onTap: onSignOut,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Sign out',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                size: 16,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
          ],
        ),
      ),
    );
  }
}


