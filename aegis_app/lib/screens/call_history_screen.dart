import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../models/call_record.dart';
import '../models/risk_level.dart';
import '../providers/history_provider.dart';

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final records = state.filteredRecords;
    final chartValues = _lastFiveDayCounts(state.records);

    if (_searchCtrl.text != state.searchQuery) {
      _searchCtrl.value = TextEditingValue(
        text: state.searchQuery,
        selection: TextSelection.collapsed(offset: state.searchQuery.length),
      );
    }

    return Container(
      decoration: const BoxDecoration(gradient: bgGradient),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                'Call Records History',
                style: GoogleFonts.rajdhani(
                  color: textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(duration: 400.ms),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _StatsCard(
                      title: 'Recent Activity (7 days)',
                      child: Row(
                        children: [
                          Text(
                            '${state.recentActivityCount}',
                            style: GoogleFonts.rajdhani(
                              color: accentTeal,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _MiniBarChart(values: chartValues)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatsCard(
                      title: 'Calls Scanned (Today)',
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${state.todayScanned}',
                            style: GoogleFonts.rajdhani(
                              color: accentTeal,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _MiniBarChart(values: chartValues)),
                        ],
                      ),
                    ),
                  ),
                ],
              ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (q) {
                        ref.read(historyProvider.notifier).setSearch(q);
                      },
                      onSubmitted: (q) {
                        ref.read(historyProvider.notifier).setSearch(q);
                      },
                      style: GoogleFonts.rajdhani(
                        color: textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by Number or Name...',
                        hintStyle: GoogleFonts.rajdhani(
                          color: textMuted,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: bgSurface,
                        side: const BorderSide(color: inputBorder, width: 0.8),
                      ),
                      onPressed: () {
                        ref
                            .read(historyProvider.notifier)
                            .setSearch(_searchCtrl.text);
                      },
                      icon: const Icon(
                        Icons.search,
                        color: accentTeal,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate(delay: 150.ms).fadeIn(duration: 400.ms),
            const SizedBox(height: 12),
            if (state.isSyncing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: LinearProgressIndicator(color: accentTeal, minHeight: 2),
              ),
            if (state.syncError != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Text(
                  state.syncError!,
                  style: GoogleFonts.rajdhani(color: riskYellow, fontSize: 12),
                ),
              ),
            if (state.isSyncing || state.syncError != null)
              const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.sort, color: textSecondary, size: 20),
                  const SizedBox(width: 8),
                  _FilterDropdown(
                    current: state.filterPeriod,
                    onSelect: (p) {
                      ref.read(historyProvider.notifier).setFilter(p);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Text(
                        'No calls found in selected period',
                        style: GoogleFonts.rajdhani(
                          color: textMuted,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: records.length,
                      itemBuilder: (_, i) => _CallRecordTile(record: records[i])
                          .animate(delay: Duration(milliseconds: i * 60))
                          .fadeIn(duration: 300.ms),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<double> _lastFiveDayCounts(List<CallRecord> records) {
    final now = DateTime.now();
    final buckets = List<int>.filled(5, 0);
    for (final record in records) {
      final day = DateTime(
        record.callTime.year,
        record.callTime.month,
        record.callTime.day,
      );
      final today = DateTime(now.year, now.month, now.day);
      final daysAgo = today.difference(day).inDays;
      if (daysAgo >= 0 && daysAgo < 5) {
        buckets[4 - daysAgo] += 1;
      }
    }
    final maxValue = buckets.reduce((a, b) => a > b ? a : b);
    if (maxValue <= 0) {
      return List<double>.filled(5, 0.08);
    }
    return buckets.map((count) => (count / maxValue).clamp(0.08, 1.0)).toList();
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _StatsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inputBorder, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(height: 50, child: child),
        ],
      ),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<double> values;
  const _MiniBarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BarChartPainter(values));
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  const _BarChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    const labels = ['D', 'S', 'T', 'Q', 'Me'];
    final barW = size.width / (labels.length * 2.2);
    final spacing = size.width / labels.length;

    for (int i = 0; i < labels.length; i++) {
      final ratio = i < values.length ? values[i] : 0.08;
      final h = ratio * size.height;
      final x = i * spacing + spacing / 2 - barW / 2;
      final isActive = i == labels.length - 1;

      final paint = Paint()
        ..color = isActive ? accentTeal : accentTealDim.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barW, h),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _FilterDropdown extends StatelessWidget {
  final FilterPeriod current;
  final ValueChanged<FilterPeriod> onSelect;

  const _FilterDropdown({required this.current, required this.onSelect});

  String _label(FilterPeriod p) {
    return switch (p) {
      FilterPeriod.today => 'Today',
      FilterPeriod.sevenDays => 'Last 7 Days',
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<FilterPeriod>(
      initialValue: current,
      color: bgSurface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: inputBorder),
      ),
      onSelected: onSelect,
      itemBuilder: (context) => FilterPeriod.values
          .map(
            (p) => PopupMenuItem<FilterPeriod>(
              value: p,
              child: Text(
                _label(p),
                style: GoogleFonts.rajdhani(
                  color: p == current ? accentTeal : textSecondary,
                  fontWeight: p == current ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: inputBorder, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(current),
              style: GoogleFonts.rajdhani(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, color: textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}

class _CallRecordTile extends StatelessWidget {
  final CallRecord record;
  const _CallRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM dd').format(record.callTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inputBorder, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentTealDark,
              border: Border.all(color: inputBorder),
            ),
            child: record.avatarAsset != null
                ? ClipOval(
                    child: Image.asset(record.avatarAsset!, fit: BoxFit.cover),
                  )
                : Icon(
                    _callerIcon(record.callerName),
                    color: textSecondary,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.callerName,
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: record.riskLevel.color,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${record.riskLevel.label} (${record.riskScore}%)',
                      style: GoogleFonts.rajdhani(
                        color: record.riskLevel.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            dateStr,
            style: GoogleFonts.rajdhani(color: textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  IconData _callerIcon(String name) {
    final l = name.toLowerCase();
    if (l.contains('delivery') || l.contains('service')) {
      return Icons.local_shipping_outlined;
    }
    if (l.contains('unknown')) return Icons.phone_outlined;
    return Icons.person_outline;
  }
}
