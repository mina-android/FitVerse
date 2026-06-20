import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  final String   label;
  final String   value;
  final String   unit;
  final IconData icon;
  final Color    iconColor;
  final List<Color> gradient;
  final bool     isLive;
  final bool     unavailable;
  /// When true, this metric is showing the last value synced to Firestore
  /// (not a live sensor reading).  Displays a grey "Synced" badge.
  final bool     isCached;
  /// Displayed inside the "Synced" badge (e.g. "2 h ago").  Ignored when
  /// [isCached] is false.
  final String?  cachedLabel;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.iconColor,
    required this.gradient,
    this.isLive      = false,
    this.unavailable = false,
    this.isCached    = false,
    this.cachedLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Determine which badge to show (priority: live > cached > unavailable > none)
    final showLive        = isLive && !unavailable;
    final showCached      = isCached && !isLive && !unavailable;
    final showUnavailable = unavailable && !isCached;

    return Opacity(
      opacity: showUnavailable ? 0.45 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: iconColor.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),

                // Badge
                if (showLive)    _LiveBadge()
                else if (showCached)  _CachedBadge(label: cachedLabel)
                else if (showUnavailable) _UnavailableBadge(),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   26,
                        fontWeight: FontWeight.bold,
                        height:     1,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          unit,
                          style: TextStyle(
                            color:    Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  showUnavailable ? '$label\n(Health Connect)' : label,
                  style: TextStyle(
                    color:    Colors.white.withOpacity(0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Badge widgets ──────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF66BB6A).withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF66BB6A), shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          const Text('Live',
              style: TextStyle(
                  color: Color(0xFF66BB6A),
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ]),
      );
}

class _CachedBadge extends StatelessWidget {
  final String? label;
  const _CachedBadge({this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_done_outlined,
              color: Colors.white.withOpacity(0.45), size: 9),
          const SizedBox(width: 3),
          Text(
            label != null ? 'Synced $label' : 'Synced',
            style: TextStyle(
                color:      Colors.white.withOpacity(0.45),
                fontSize:   9,
                fontWeight: FontWeight.w600),
          ),
        ]),
      );
}

class _UnavailableBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Needs HC',
          style: TextStyle(
              color:      Colors.white.withOpacity(0.45),
              fontSize:   9,
              fontWeight: FontWeight.w600),
        ),
      );
}
