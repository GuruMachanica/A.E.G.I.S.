import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../core/constants.dart';
import '../widgets/risk_gauge.dart';
import '../models/call_record.dart';
import '../providers/call_monitor_provider.dart';
import '../providers/home_provider.dart';
import '../providers/history_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/aegis_logo.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final history = ref.watch(historyProvider);
    final monitor = ref.watch(callMonitorProvider);

    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: const SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: accentTeal,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Loading security dashboard...',
                  style: TextStyle(color: textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final score = _securityScore(history.records);
    final scoreColor = score >= 75
        ? riskGreen
        : score >= 45
        ? riskYellow
        : riskRed;

    final recentAlerts =
        history.records.where((r) => r.riskScore >= 50).toList()
          ..sort((a, b) => b.callTime.compareTo(a.callTime));
    final usingPlaceholderBackend =
        backendBaseUrl.contains('10.0.2.2') ||
        backendBaseUrl.contains('localhost') ||
        backendBaseUrl.contains('example.com');

    return Container(
      decoration: const BoxDecoration(gradient: bgGradient),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const AegisLogo(
                    size: 38,
                    assetPath: 'assets/images/aegis_app_logo.png',
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'A.E.G.I.S.',
                    style: GoogleFonts.rajdhani(
                      color: textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (usingPlaceholderBackend) ...[
                      _ConfigWarningCard(baseUrl: backendBaseUrl),
                      const SizedBox(height: 12),
                    ],
                    _SystemStatusCard(enabled: home.detectionEnabled),
                    const SizedBox(height: 12),
                    _MonitoringIndicatorCard(monitor: monitor),
                    const SizedBox(height: 12),
                    _AiRiskInsightCard(monitor: monitor),
                    const SizedBox(height: 12),
                    _SecurityScoreCard(score: score, color: scoreColor),
                    const SizedBox(height: 12),
                    _StatsRow(history: history),
                    const SizedBox(height: 12),
                    if (home.lastThreat != null)
                      _ThreatCard(record: home.lastThreat!).animate().fadeIn(),
                    const SizedBox(height: 12),
                    _RecentAlertsCard(records: recentAlerts.take(2).toList()),
                    const SizedBox(height: 14),
                    _DetectionToggle(
                      enabled: home.detectionEnabled,
                      onToggle: () {
                        final wasEnabled = home.detectionEnabled;
                        ref.read(homeProvider.notifier).toggleDetection();
                        if (!wasEnabled) context.push('/home/monitor');
                      },
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Quick Access',
                      style: GoogleFonts.rajdhani(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickAccessCard(
                            icon: Icons.phone_outlined,
                            label: 'Last Call Details',
                            onTap: _showLastCallDetails,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _QuickAccessCard(
                            icon: Icons.article_outlined,
                            label: 'History',
                            onTap: () => ref
                                .read(navigationProvider.notifier)
                                .setIndex(1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _securityScore(List<CallRecord> records) {
    final suspicious = records
        .where((r) => r.riskScore >= 35 && r.riskScore < 65)
        .length;
    final danger = records.where((r) => r.riskScore >= 65).length;
    final value = 100 - (suspicious * 8) - (danger * 15);
    return value.clamp(0, 100);
  }

  void _showLastCallDetails() {
    final records = ref.read(historyProvider).records;
    if (records.isEmpty) return;
    final last = [...records]..sort((a, b) => b.callTime.compareTo(a.callTime));
    final record = last.first;
    showModalBottomSheet(
      context: context,
      backgroundColor: bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Call Analysis',
              style: GoogleFonts.rajdhani(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${record.callerName} • ${record.phoneNumber}',
              style: GoogleFonts.rajdhani(color: textSecondary, fontSize: 13),
            ),
            Text(
              DateFormat('MMM dd, hh:mm a').format(record.callTime),
              style: GoogleFonts.rajdhani(color: textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            _AnalysisLine('Overall Risk', '${record.riskScore}%'),
            _AnalysisLine('Synthetic Voice', '${record.syntheticScore}%'),
            _AnalysisLine('Scam Intent', '${record.intentScore}%'),
          ],
        ),
      ),
    );
  }
}

class _SystemStatusCard extends StatelessWidget {
  final bool enabled;
  const _SystemStatusCard({required this.enabled});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? riskGreen : riskRed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Status',
            style: GoogleFonts.rajdhani(color: textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            enabled ? 'AI Protection Active' : 'Protection Disabled',
            style: GoogleFonts.rajdhani(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            enabled
                ? 'Microphone Monitoring Enabled'
                : 'Turn on Threat Protection',
            style: GoogleFonts.rajdhani(color: textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ConfigWarningCard extends StatelessWidget {
  final String baseUrl;
  const _ConfigWarningCard({required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: riskYellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: riskYellow.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Environment Notice',
            style: GoogleFonts.rajdhani(
              color: riskYellow,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Using non-production backend: $baseUrl',
            style: GoogleFonts.rajdhani(color: textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MonitoringIndicatorCard extends StatelessWidget {
  final CallMonitorState monitor;
  const _MonitoringIndicatorCard({required this.monitor});

  @override
  Widget build(BuildContext context) {
    final text = monitor.isMonitoring
        ? 'AI listening for scam patterns'
        : monitor.isConnecting
        ? 'Connecting secure scanner...'
        : 'No call currently monitored';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inputBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.call, color: accentTeal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Call Monitoring',
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  text,
                  style: GoogleFonts.rajdhani(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiRiskInsightCard extends StatelessWidget {
  final CallMonitorState monitor;
  const _AiRiskInsightCard({required this.monitor});

  @override
  Widget build(BuildContext context) {
    final percent = (monitor.overallFraudScore * 100).round();
    final level = monitor.safeRiskLevel.toLowerCase();
    final levelText = level == 'danger'
        ? 'High Risk'
        : level == 'warning'
        ? 'Moderate Risk'
        : 'Low Risk';
    final levelColor = level == 'danger'
        ? riskRed
        : level == 'warning'
        ? riskYellow
        : riskGreen;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Call Scan — AI Analysis',
            style: GoogleFonts.rajdhani(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Risk Assessment: $levelText ($percent%)',
            style: GoogleFonts.rajdhani(
              color: levelColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            monitor.safeDetectedKeywords.isEmpty
                ? 'No sensitive keywords detected in current stream.'
                : 'Keywords: ${monitor.safeDetectedKeywords.join(', ')}',
            style: GoogleFonts.rajdhani(color: textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SecurityScoreCard extends StatelessWidget {
  final int score;
  final Color color;
  const _SecurityScoreCard({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inputBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Security Score',
                  style: GoogleFonts.rajdhani(color: textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '$score / 100',
                  style: GoogleFonts.rajdhani(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 90, height: 90, child: RiskGauge(score: score / 100)),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final HistoryState history;
  const _StatsRow({required this.history});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            'Threats Blocked Today',
            '${history.blockedThreatsToday}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _MiniStat('Calls Scanned', '${history.todayScanned}')),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat('Suspicious Calls', '${history.suspiciousCalls}'),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;
  const _MiniStat(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inputBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: accentTeal,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(color: textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _RecentAlertsCard extends StatelessWidget {
  final List<CallRecord> records;
  const _RecentAlertsCard({required this.records});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Alerts',
            style: GoogleFonts.rajdhani(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (records.isEmpty)
            Text(
              'No recent scam alerts.',
              style: GoogleFonts.rajdhani(color: textMuted),
            )
          else
            ...records.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ${r.callerName}',
                      style: GoogleFonts.rajdhani(
                        color: textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      DateFormat('MMM dd, hh:mm a').format(r.callTime),
                      style: GoogleFonts.rajdhani(
                        color: textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThreatCard extends StatelessWidget {
  final CallRecord record;
  const _ThreatCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2A0D0D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: riskRed.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PulsingDot(),
                    const SizedBox(width: 8),
                    Text(
                      'Threat Detected!',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _InfoLine('Source:', record.callerName),
                const SizedBox(height: 4),
                _InfoLine(
                  'Call Status:',
                  record.isSuspended
                      ? 'Call Suspended (AI Verified)'
                      : 'Monitoring',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              RiskGauge(score: record.riskScore / 100, size: 100),
              Text(
                'Risk Score',
                style: GoogleFonts.rajdhani(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: riskRed.withValues(alpha: 0.5 + _c.value * 0.5),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.rajdhani(color: textSecondary, fontSize: 13),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: value,
            style: GoogleFonts.rajdhani(color: textPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DetectionToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onToggle;
  const _DetectionToggle({required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final active = enabled;
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 82,
        decoration: BoxDecoration(
          color: active ? accentTeal : accentTealDark,
          borderRadius: BorderRadius.circular(34),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accentTeal.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Threat Protection',
                    style: GoogleFonts.rajdhani(
                      color: active ? bgPrimary : textSecondary,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    active
                        ? 'Monitoring enabled for live calls'
                        : 'Tap to protect your live call',
                    style: GoogleFonts.rajdhani(
                      color: active
                          ? bgPrimary.withValues(alpha: 0.8)
                          : textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 42,
              height: 26,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    left: active ? 18 : 2,
                    top: 2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalysisLine extends StatelessWidget {
  final String label;
  final String value;
  const _AnalysisLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.rajdhani(color: textSecondary)),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAccessCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: inputBorder, width: 0.8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textSecondary, size: 32),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
