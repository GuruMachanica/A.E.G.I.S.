import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/colors.dart';
import '../models/call_record.dart';
import '../providers/call_monitor_provider.dart';
import '../providers/history_provider.dart';
import '../providers/home_provider.dart';
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
    Future.delayed(const Duration(milliseconds: 600), () {
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
        color: bgPrimary,
        child: const SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    color: accentCyan,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'SYNCING 100% ON-DEVICE VAULT...',
                  style: TextStyle(
                    color: textSecondary,
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final score = _securityScore(history.records);
    final scoreColor = score >= 75
        ? accentEmerald
        : score >= 45
            ? riskYellow
            : riskRed;

    final recentAlerts =
        history.records.where((r) => r.riskScore >= 50).toList()
          ..sort((a, b) => b.callTime.compareTo(a.callTime));

    return Container(
      color: bgPrimary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top HUD Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  const AegisLogo(
                    size: 38,
                    showGlow: false,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A.E.G.I.S.',
                        style: GoogleFonts.rajdhani(
                          color: textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.5,
                        ),
                      ),
                      Text(
                        'DEFENSE HUB • V2.0',
                        style: GoogleFonts.jetBrainsMono(
                          color: textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Active Protection Armed Chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accentEmerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentEmerald.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: accentEmerald,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accentEmerald,
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '100% LOCAL',
                          style: GoogleFonts.rajdhani(
                            color: accentEmerald,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // ── Central Cyber Shield Core Card ───────────────────────
                    _CyberShieldCore(
                      score: score,
                      scoreColor: scoreColor,
                      enabled: home.detectionEnabled,
                      onToggle: () {
                        ref.read(homeProvider.notifier).toggleDetection();
                      },
                      onLaunchLive: () => context.push('/home/monitor'),
                    ),

                    const SizedBox(height: 16),

                    // ── 3 Telemetry Data Cards ───────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _TelemetryCard(
                            label: 'SCANNED',
                            value: '${history.todayScanned}',
                            subtext: 'Calls Today',
                            icon: Icons.shield_outlined,
                            accentColor: accentCyan,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TelemetryCard(
                            label: 'NEUTRALIZED',
                            value: '${history.blockedThreatsToday}',
                            subtext: 'Threats Blocked',
                            icon: Icons.gpp_bad_outlined,
                            accentColor: history.blockedThreatsToday > 0
                                ? riskRed
                                : textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TelemetryCard(
                            label: 'EDGE LATENCY',
                            value: '0ms',
                            subtext: 'Pure On-Device',
                            icon: Icons.bolt_rounded,
                            accentColor: accentEmerald,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Active Monitoring Card (if call is live) ─────────────
                    if (monitor.isMonitoring) ...[
                      _LiveCallQuickCard(monitor: monitor),
                      const SizedBox(height: 16),
                    ],

                    // ── Threat Intel Radar (India localized vectors) ────────
                    _ThreatIntelRadarCard(),

                    const SizedBox(height: 16),

                    // ── Recent Forensic Alerts ──────────────────────────────
                    if (recentAlerts.isNotEmpty) ...[
                      Text(
                        'CRITICAL INCIDENT LOGS',
                        style: GoogleFonts.rajdhani(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...recentAlerts.take(2).map(
                            (r) => _IncidentCard(
                              record: r,
                              onTap: () => _showRecordDetails(r),
                            ),
                          ),
                      const SizedBox(height: 16),
                    ],

                    // ── Quick Access Buttons ─────────────────────────────────
                    Text(
                      'TACTICAL ACCESS',
                      style: GoogleFonts.rajdhani(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickButton(
                            icon: Icons.mic_rounded,
                            title: 'Launch Live Monitor',
                            subtitle: 'Real-time Audio Intercept',
                            accent: accentCyan,
                            onTap: () => context.push('/home/monitor'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickButton(
                            icon: Icons.folder_shared_outlined,
                            title: 'Evidence Vault',
                            subtitle: 'Call Logs & Dossiers',
                            accent: accentEmerald,
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

  void _showRecordDetails(CallRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: inputBorder),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security_rounded, color: accentCyan, size: 20),
                const SizedBox(width: 8),
                Text(
                  'INCIDENT FORENSIC OVERVIEW',
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Target: ${record.callerName} • ${record.phoneNumber}',
              style: GoogleFonts.rajdhani(
                color: textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              DateFormat('MMM dd, yyyy • hh:mm a').format(record.callTime),
              style: GoogleFonts.jetBrainsMono(
                color: textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),
            _AnalysisLine('Overall Threat Score', '${record.riskScore}%'),
            _AnalysisLine('Synthetic Voice Index', '${record.syntheticScore}%'),
            _AnalysisLine('Scam Intent Score', '${record.intentScore}%'),
            _AnalysisLine(
              'Status',
              record.isSuspended ? 'QUARANTINED' : 'CLEARED',
            ),
          ],
        ),
      ),
    );
  }
}

class _CyberShieldCore extends StatelessWidget {
  final int score;
  final Color scoreColor;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onLaunchLive;

  const _CyberShieldCore({
    required this.score,
    required this.scoreColor,
    required this.enabled,
    required this.onToggle,
    required this.onLaunchLive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? accentCyan.withValues(alpha: 0.3) : inputBorder,
          width: 1.2,
        ),
        boxShadow: [
          if (enabled)
            BoxShadow(
              color: accentCyan.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Row(
        children: [
          // Circular shield meter
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 82,
                height: 82,
                child: CircularProgressIndicator(
                  value: enabled ? score / 100.0 : 0.0,
                  strokeWidth: 6,
                  color: enabled ? scoreColor : textMuted,
                  backgroundColor: bgPrimary,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    enabled ? '$score%' : 'OFF',
                    style: GoogleFonts.rajdhani(
                      color: textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'SHIELD',
                    style: GoogleFonts.jetBrainsMono(
                      color: textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'SYSTEM STATUS: ARMED' : 'SYSTEM STATUS: STANDBY',
                  style: GoogleFonts.rajdhani(
                    color: enabled ? accentEmerald : riskYellow,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? 'Autonomous on-device acoustic & intent defense is guarding incoming audio.'
                      : 'Call defense is currently paused. Tap below to activate protection.',
                  style: GoogleFonts.rajdhani(
                    color: textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: onToggle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: enabled ? bgPrimary : accentCyan,
                        foregroundColor: enabled ? textPrimary : bgPrimary,
                        side: BorderSide(
                          color: enabled ? inputBorder : accentCyan,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        enabled ? 'PAUSE' : 'ARM SHIELD',
                        style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onLaunchLive,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: accentCyan),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'LIVE MONITOR',
                        style: GoogleFonts.rajdhani(
                          color: accentCyan,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final IconData icon;
  final Color accentColor;

  const _TelemetryCard({
    required this.label,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: accentColor,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtext,
            style: GoogleFonts.rajdhani(
              color: textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveCallQuickCard extends StatelessWidget {
  final CallMonitorState monitor;
  const _LiveCallQuickCard({required this.monitor});

  @override
  Widget build(BuildContext context) {
    final isDanger = monitor.isHighRisk;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isDanger ? riskRed : accentCyan).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDanger ? riskRed : accentCyan).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.record_voice_over_rounded,
            color: isDanger ? riskRed : accentCyan,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVE CALL IN PROGRESS',
                  style: GoogleFonts.rajdhani(
                    color: isDanger ? riskRed : accentCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  monitor.activeCallNumber,
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.push('/home/monitor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDanger ? riskRed : accentCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: Text(
              'VIEW HUD',
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreatIntelRadarCard extends StatelessWidget {
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
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: accentCyan, size: 16),
              const SizedBox(width: 6),
              Text(
                'LIVE SCAM VECTOR RADAR (INDIA)',
                style: GoogleFonts.rajdhani(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _VectorItem('Digital Arrest Police Extortion', 'HIGH SEVERITY', riskRed),
          _VectorItem('Electricity Bill Immediate KYC Disconnect', 'URGENT', riskYellow),
          _VectorItem('Customs Parcel Courier Narcotics Scam', 'ACTIVE', riskYellow),
        ],
      ),
    );
  }

  Widget _VectorItem(String name, String tag, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.rajdhani(
                color: textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tag,
              style: GoogleFonts.jetBrainsMono(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final CallRecord record;
  final VoidCallback onTap;

  const _IncidentCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: inputBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: riskRed.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_rounded, color: riskRed, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.phoneNumber,
                  style: GoogleFonts.rajdhani(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  DateFormat('MMM dd • hh:mm a').format(record.callTime),
                  style: GoogleFonts.jetBrainsMono(
                    color: textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${record.riskScore}% THREAT',
            style: GoogleFonts.rajdhani(
              color: riskRed,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _QuickButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: inputBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.rajdhani(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.rajdhani(
                color: textMuted,
                fontSize: 10,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
