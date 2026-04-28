import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import '../services/app_enrichment_service.dart';

/// Rich detail panel shown on the right side of the master-detail split when
/// an installed app is selected.
class InstalledAppDetailPanel extends StatefulWidget {
  final AppInfo? app;
  final List<dynamic> dbApps;
  final Set<String> favoritePackages;
  final ValueChanged<String> onToggleFavorite;
  final VoidCallback? onUninstall;

  const InstalledAppDetailPanel({
    super.key,
    required this.app,
    required this.dbApps,
    required this.favoritePackages,
    required this.onToggleFavorite,
    this.onUninstall,
  });

  @override
  State<InstalledAppDetailPanel> createState() =>
      _InstalledAppDetailPanelState();
}

class _InstalledAppDetailPanelState extends State<InstalledAppDetailPanel> {
  String? _sizeLabel;
  bool _loadingSize = false;

  String _description = '';
  bool _loadingDescription = false;

  @override
  void initState() {
    super.initState();
    _loadSize();
    _loadDescription();
  }

  @override
  void didUpdateWidget(InstalledAppDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app?.packageName != widget.app?.packageName) {
      _sizeLabel = null;
      _description = '';
      _loadSize();
      _loadDescription();
    }
  }

  Future<void> _loadSize() async {
    final app = widget.app;
    if (app == null) return;
    setState(() => _loadingSize = true);
    final label = await AppEnrichmentService.instance.getAppSizeLabel(app);
    if (mounted)
      setState(() {
        _sizeLabel = label;
        _loadingSize = false;
      });
  }

  Future<void> _loadDescription() async {
    final app = widget.app;
    if (app == null) return;
    // Instant DB lookup first
    final quick = AppEnrichmentService.instance.getDescription(
      app.packageName,
      widget.dbApps,
    );
    if (quick.isNotEmpty) {
      if (mounted) setState(() => _description = quick);
      return;
    }
    // Async fallback (Google Play)
    if (mounted) setState(() => _loadingDescription = true);
    final fetched = await AppEnrichmentService.instance.fetchDescription(
      app.packageName,
      widget.dbApps,
    );
    if (mounted)
      setState(() {
        _description = fetched;
        _loadingDescription = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    if (app == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 56,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'Select an app to see details',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    final isFavorite = widget.favoritePackages.contains(app.packageName);
    final dbApp = AppEnrichmentService.instance.getDbApp(
      app.packageName,
      widget.dbApps,
    );

    final installDate = app.installedTimestamp != 0
        ? DateTime.fromMillisecondsSinceEpoch(app.installedTimestamp)
        : null;
    final installDateStr = installDate != null
        ? '${installDate.year}-'
              '${installDate.month.toString().padLeft(2, '0')}-'
              '${installDate.day.toString().padLeft(2, '0')}'
        : 'Unknown';

    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AppIconHero(icon: app.icon),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: app.packageName));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Package name copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              app.packageName,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.copy_outlined,
                            size: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Genres / category chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (dbApp != null) ...[
                          if ((dbApp['genres'] ?? dbApp['category'] ?? '')
                              .toString()
                              .isNotEmpty)
                            _Chip(
                              icon: Icons.category_outlined,
                              label:
                                  (dbApp['genres'] ?? dbApp['category'] ?? '')
                                      .toString()
                                      .split(',')
                                      .first
                                      .trim(),
                              color: colorScheme.secondary,
                            ),
                          if (dbApp['ovrport'] == 1 ||
                              dbApp['ovrport'] == true ||
                              dbApp['ovrport'] == 'true')
                            _Chip(
                              icon: Icons.warning_amber_outlined,
                              label: 'Ovrport',
                              color: Colors.orange,
                            ),
                        ],
                        if (app.isSystemApp)
                          _Chip(
                            icon: Icons.settings,
                            label: 'System',
                            color: Colors.blueGrey,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorite ? Colors.amber : null,
                  size: 28,
                ),
                onPressed: () => widget.onToggleFavorite(app.packageName),
                tooltip: isFavorite ? 'Remove favorite' : 'Add to favorites',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Metadata grid ─────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _MetaRow(
                  icon: Icons.label_outline,
                  label: 'Version',
                  value: '${app.versionName}  (build\u00a0${app.versionCode})',
                ),
                const Divider(height: 16, thickness: 0.5),
                _MetaRow(
                  icon: Icons.storage_outlined,
                  label: 'APK Size',
                  value: _loadingSize
                      ? 'Loading\u2026'
                      : (_sizeLabel ?? 'Unknown'),
                ),
                const Divider(height: 16, thickness: 0.5),
                _MetaRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Installed',
                  value: installDateStr,
                ),
                if (dbApp != null) ...[
                  const Divider(height: 16, thickness: 0.5),
                  _MetaRow(
                    icon: Icons.update_outlined,
                    label: 'DB Version',
                    value: (dbApp['version'] ?? '—').toString(),
                  ),
                  if ((dbApp['size_bytes_apk'] ?? 0) > 0) ...[
                    const Divider(height: 16, thickness: 0.5),
                    _MetaRow(
                      icon: Icons.folder_zip_outlined,
                      label: 'Download Size',
                      value: _formatCatalogBytes(
                        (dbApp['size_bytes_apk'] as num?)?.toInt() ?? 0,
                        (dbApp['size_bytes_obb'] as num?)?.toInt() ?? 0,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Description ───────────────────────────────────────────────────
          Text(
            'About',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_loadingDescription)
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Fetching description…',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          else if (_description.isNotEmpty)
            _ExpandableDescription(text: _description)
          else
            Text(
              'No description available.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
          const SizedBox(height: 20),

          // ── Action buttons ─────────────────────────────────────────────────
          Text(
            'Actions',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => InstalledApps.startApp(app.packageName),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Launch'),
              ),
              OutlinedButton.icon(
                onPressed: () => InstalledApps.openSettings(app.packageName),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('App Settings'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onUninstall,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  'Uninstall',
                  style: TextStyle(color: Colors.redAccent),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCatalogBytes(int apkBytes, int obbBytes) {
    final total = apkBytes + obbBytes;
    return AppEnrichmentService.formatBytes(total);
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _AppIconHero extends StatelessWidget {
  final Uint8List? icon;
  const _AppIconHero({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: icon != null
          ? Image.memory(icon!, fit: BoxFit.cover)
          : const ColoredBox(
              color: Colors.black26,
              child: Icon(Icons.android, size: 44, color: Colors.white70),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.5);
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ExpandableDescription extends StatefulWidget {
  final String text;
  const _ExpandableDescription({required this.text});

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: TextStyle(
            fontSize: 13,
            height: 1.55,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          maxLines: _expanded ? null : 5,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (widget.text.length > 200) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Show less' : 'Show more',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
