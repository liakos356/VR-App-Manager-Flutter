import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/google_drive_service.dart';
import '../utils/localization.dart';

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

  Color _panelBg(bool isDark) =>
      isDark ? const Color(0xFF252526) : Colors.white;

  Color _borderColor(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.09);

  Color _mutedText(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.45)
      : Colors.black.withValues(alpha: 0.38);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: isOpen ? 320 : 0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _panelBg(isDark),
        border: Border(left: BorderSide(color: _borderColor(isDark), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: isOpen
          ? _OpenPanel(
              isOpen: isOpen,
              onToggle: onToggle,
              ovrportFilter: ovrportFilter,
              onOvrportFilterChanged: onOvrportFilterChanged,
              availableOnly: availableOnly,
              onAvailableOnlyChanged: onAvailableOnlyChanged,
              updatedRecentlyFilter: updatedRecentlyFilter,
              onUpdatedRecentlyFilterChanged: onUpdatedRecentlyFilterChanged,
              updatedRecentlyDays: updatedRecentlyDays,
              onUpdatedRecentlyDaysChanged: onUpdatedRecentlyDaysChanged,
              onReloadDatabase: onReloadDatabase,
              onOpenInstalledApps: onOpenInstalledApps,
              onOpenAppUpdater: onOpenAppUpdater,
            )
          : _CollapsedStrip(
              onToggle: onToggle, // width is 0; this is never visible
              mutedText: _mutedText(isDark),
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
    final colorScheme = Theme.of(context).colorScheme;
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.38);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          children: [
            Tooltip(
              message: 'Close Settings',
              child: IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: onToggle,
              ),
            ),
            const Text(
              'Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Divider(height: 1),

        // ── Scrollable body ─────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Language ─────────────────────────────────────────────
                ValueListenableBuilder<bool>(
                  valueListenable: isGreekNotifier,
                  builder: (context, isGreek, _) {
                    return ListTile(
                      leading: const Icon(Icons.language),
                      title: const Text('Language'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isGreek ? 'GR' : 'EN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      onTap: () async {
                        isGreekNotifier.value = !isGreekNotifier.value;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('isGreek', isGreekNotifier.value);
                      },
                    );
                  },
                ),

                // ── Theme ────────────────────────────────────────────────
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, mode, _) {
                    final dark = mode == ThemeMode.dark;
                    return ListTile(
                      leading: Icon(dark ? Icons.light_mode : Icons.dark_mode),
                      title: const Text('Theme'),
                      trailing: Text(
                        dark ? 'Dark' : 'Light',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () async {
                        final newMode = dark ? ThemeMode.light : ThemeMode.dark;
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

                // ── Accent Color ─────────────────────────────────────────
                ValueListenableBuilder<int>(
                  valueListenable: accentIndexNotifier,
                  builder: (context, accentIdx, _) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.palette_outlined,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Accent Color',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: List.generate(accentColorOptions.length, (
                              i,
                            ) {
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
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.setInt('accentColorIndex', i);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
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
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // ── Ovrport Only ─────────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.vrpano_outlined),
                  title: const Text('Ovrport Only'),
                  subtitle: const Text('Show only Ovrport-compatible apps'),
                  trailing: Switch(
                    value: ovrportFilter,
                    onChanged: onOvrportFilterChanged,
                  ),
                ),

                // ── Available Only ───────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Available Only'),
                  subtitle: const Text('Hide apps not on the server'),
                  trailing: Switch(
                    value: availableOnly,
                    onChanged: onAvailableOnlyChanged,
                  ),
                ),

                // ── Updated Recently ─────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.new_releases_outlined),
                  title: const Text('Updated Recently'),
                  subtitle: Text(
                    'Show only apps updated in the last $updatedRecentlyDays'
                    ' day${updatedRecentlyDays == 1 ? '' : 's'}',
                  ),
                  trailing: Switch(
                    value: updatedRecentlyFilter,
                    onChanged: onUpdatedRecentlyFilterChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: updatedRecentlyDays.toDouble(),
                          min: 1,
                          max: 90,
                          divisions: 89,
                          label: '$updatedRecentlyDays d',
                          onChanged: (v) =>
                              onUpdatedRecentlyDaysChanged(v.round()),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '$updatedRecentlyDays d',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Reload Database ──────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Reload Database'),
                  onTap: onReloadDatabase,
                ),
                const Divider(),

                // ── Installed Apps ───────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.install_mobile),
                  title: const Text('Installed Apps'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: onOpenInstalledApps,
                ),

                // ── App Updater ──────────────────────────────────────────
                ListTile(
                  leading: const Icon(Icons.system_update_alt_outlined),
                  title: const Text('App Updater'),
                  subtitle: const Text(
                    'Browse & install app versions from Drive',
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: onOpenAppUpdater,
                ),
                const Divider(),

                // ── Google Drive Account ─────────────────────────────────
                ValueListenableBuilder<GoogleUserInfo?>(
                  valueListenable: GoogleDriveService().userNotifier,
                  builder: (ctx, user, _) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user?.photoUrl != null
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                      child: user?.photoUrl == null
                          ? const Icon(Icons.account_circle_outlined)
                          : null,
                    ),
                    title: const Text('Google Drive'),
                    subtitle: Text(
                      user?.email ?? 'Not connected — tap to sign in',
                    ),
                    trailing: user != null
                        ? TextButton(
                            onPressed: () => GoogleDriveService().signOut(),
                            child: const Text('Sign out'),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: user == null
                        ? () async {
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
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Muted footer ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'VR App Manager',
                    style: TextStyle(fontSize: 11, color: mutedColor),
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
