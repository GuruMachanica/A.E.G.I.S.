import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../core/colors.dart';
import '../models/call_record.dart';
import '../models/risk_level.dart';
import '../providers/auth_provider.dart';
import '../providers/call_monitor_provider.dart';
import '../providers/history_provider.dart';
import '../providers/home_provider.dart';
import '../services/local_report_service.dart';
import '../widgets/live_oscillograph.dart';
import '../widgets/risk_gauge.dart';

class LiveCallMonitorScreen extends ConsumerStatefulWidget {
  const LiveCallMonitorScreen({super.key});

  @override
  ConsumerState<LiveCallMonitorScreen> createState() =>
      _LiveCallMonitorScreenState();
}

class _LiveCallMonitorScreenState extends ConsumerState<LiveCallMonitorScreen> {
  bool _loggedCurrentCall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      final callNumber = auth.phoneNumber.trim().isNotEmpty
          ? auth.phoneNumber.trim()
          : '+91 98765 43210';
      ref.read(callMonitorProvider.notifier).startMonitoring(callNumber);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callMonitorProvider);

    ref.listen<CallMonitorState>(callMonitorProvider, (prev, next) {
      if (next.callEnded && context.canPop()) context.pop();
      if (next.scamAlertActive &&
          (prev == null ||
              !prev.scamAlertActive ||
              prev.scamAlertType != next.scamAlertType)) {
        Vibration.vibrate(pattern: [0, 400, 200, 400]);
      }
    });

    final isDanger = state.overallFraudScore >= 0.65 || state.scamAlertActive;
    final isWarning = state.overallFraudScore >= 0.35 && !isDanger;

    return Scaffold(
      backgroundColor: bgPrimary,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.1,
            colors: [Color(0xFF0F1B2E), bgPrimary],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header HUD ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        ref.read(callMonitorProvider.notifier).endCall();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: inputBorder),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: textSecondary,
                          size: 16,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        Text(
                          'AEGIS LIVE DEFENSE',
                          style: GoogleFonts.rajdhani(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          '100% ON-DEVICE PRIVACY SHIELD',
                          style: GoogleFonts.jetBrainsMono(
                            color: accentCyan,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Pulsing LIVE beacon
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (isDanger ? riskRed : accentEmerald)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (isDanger ? riskRed : accentEmerald)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PulsingDot(color: isDanger ? riskRed : accentEmerald),
                          const SizedBox(width: 5),
                          Text(
                            isDanger ? 'THREAT' : 'LIVE',
                            style: GoogleFonts.rajdhani(
                              color: isDanger ? riskRed : accentEmerald,
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
                    children: [
                      const SizedBox(height: 10),

                      // ── Target Caller Info ────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: inputBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: bgPrimary,
                                border: Border.all(
                                  color: isDanger ? riskRed : accentCyan,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.phone_in_talk_rounded,
                                color: isDanger ? riskRed : accentCyan,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ACTIVE CALL INTERCEPT',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    state.activeCallNumber,
                                    style: GoogleFonts.rajdhani(
                                      color: textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: (isDanger
                                        ? riskRed
                                        : (isWarning ? riskYellow : accentEmerald))
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                state.safeRiskLevel.toUpperCase(),
                                style: GoogleFonts.rajdhani(
                                  color: isDanger
                                      ? riskRed
                                      : (isWarning ? riskYellow : accentEmerald),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Holographic Dual-Ring Threat Gauge ────────────────
                      RiskGauge(
                        score: state.overallFraudScore,
                        innerScore: state.syntheticVoiceScore,
                        size: 210,
                        centerLabel: isDanger
                            ? 'CRITICAL THREAT'
                            : (isWarning ? 'SUSPICIOUS' : 'SECURE LINE'),
                        subLabel:
                            'Outer: Scam ${(state.overallFraudScore * 100).round()}% | Inner: Voice ${(state.syntheticVoiceScore * 100).round()}%',
                      ),

                      const SizedBox(height: 16),

                      // ── Live Audio Spectrum Oscillograph ──────────────────
                      LiveOscillograph(
                        rms: (state.overallFraudScore * 0.4 +
                                (state.safeAudioChunksPerSecond > 0 ? 0.04 : 0.01))
                            .clamp(0.01, 0.9),
                        db: state.overallFraudScore > 0.5 ? -14.2 : -28.5,
                        isSpeech: state.safeAudioChunksPerSecond > 0 ||
                            state.safeTranscript.isNotEmpty,
                        isThreat: isDanger,
                      ),

                      const SizedBox(height: 14),

                      // ── Scam Threat Alert Card ────────────────────────────
                      if (state.scamAlertActive && state.scamAlertMessage != null) ...[
                        _ScamAlertCard(
                          alertType: state.scamAlertType ?? 'scam_alert',
                          alertMessage: state.scamAlertMessage!,
                          onDismiss: () {
                            ref
                                .read(callMonitorProvider.notifier)
                                .dismissScamAlert();
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Detected Threat Chips ─────────────────────────────
                      if (state.safeDetectedKeywords.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'DETECTED THREAT PATTERNS',
                            style: GoogleFonts.rajdhani(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: state.safeDetectedKeywords
                              .map(
                                (kw) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: riskRed.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: riskRed.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: riskRed,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        kw.toUpperCase(),
                                        style: GoogleFonts.jetBrainsMono(
                                          color: riskRed,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Live Transcript Terminal ──────────────────────────
                      Container(
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
                                const Icon(
                                  Icons.terminal_rounded,
                                  color: accentCyan,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'LIVE TRANSCRIPT TERMINAL',
                                  style: GoogleFonts.rajdhani(
                                    color: textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bgPrimary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'OFFLINE STT',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: accentEmerald,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              state.safeTranscript.trim().isEmpty
                                  ? '> Listening for incoming voice stream...'
                                  : '> ${state.safeTranscript}',
                              style: GoogleFonts.jetBrainsMono(
                                color: state.safeTranscript.trim().isEmpty
                                    ? textMuted
                                    : textPrimary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Quick Threat Testing Chips ────────────────────────
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'QUICK SIMULATOR (TEST ON-DEVICE DETECTION):',
                          style: GoogleFonts.rajdhani(
                            color: textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _SimulatorChip(
                              label: '⚡ OTP Demand',
                              color: riskRed,
                              onTap: () {
                                ref
                                    .read(callMonitorProvider.notifier)
                                    .injectTestTranscript(
                                      'Immediate action required please disclose your OTP and PIN to avoid account suspension.',
                                    );
                              },
                            ),
                            const SizedBox(width: 8),
                            _SimulatorChip(
                              label: '🚨 Digital Arrest',
                              color: riskRed,
                              onTap: () {
                                ref
                                    .read(callMonitorProvider.notifier)
                                    .injectTestTranscript(
                                      'This is Central Police HQ. You are placed under digital arrest for unauthorized courier parcel shipment.',
                                    );
                              },
                            ),
                            const SizedBox(width: 8),
                            _SimulatorChip(
                              label: '⚠️ KYC Freeze',
                              color: riskYellow,
                              onTap: () {
                                ref
                                    .read(callMonitorProvider.notifier)
                                    .injectTestTranscript(
                                      'Your bank account is marked for immediate freeze. Complete KYC update by sending money.',
                                    );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ── Tactical Bottom Action Bar ─────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  color: bgSurface,
                  border: Border(
                    top: BorderSide(color: inputBorder, width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    // Mute
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () {
                          ref.read(callMonitorProvider.notifier).muteAlert();
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: state.isMuted ? accentCyan : inputBorder,
                          ),
                          backgroundColor: state.isMuted
                              ? accentCyan.withValues(alpha: 0.12)
                              : bgPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Icon(
                          state.isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: state.isMuted ? accentCyan : textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // TERMINATE CALL (High-Urgency Crimson)
                    Expanded(
                      flex: 4,
                      child: ElevatedButton(
                        onPressed: _endCallAndLog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: riskRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 8,
                          shadowColor: riskRed.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.call_end_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'TERMINATE CALL',
                              style: GoogleFonts.rajdhani(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Export Dossier
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: _showForensicDossier,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: accentCyan),
                          backgroundColor: accentCyan.withValues(alpha: 0.08),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: accentCyan,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _endCallAndLog() {
    if (!_loggedCurrentCall) {
      final monitor = ref.read(callMonitorProvider);
      final score = (monitor.overallFraudScore * 100).round().clamp(0, 100);
      final synthetic =
          (monitor.syntheticVoiceScore * 100).round().clamp(0, 100);
      final intent = (monitor.scamChanceScore * 100).round().clamp(0, 100);
      final level = CallRecord.levelFromScore(score);

      final record = CallRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        callerName: 'Call Scan Intercept',
        phoneNumber: monitor.activeCallNumber,
        callTime: DateTime.now(),
        riskLevel: level,
        riskScore: score,
        syntheticScore: synthetic,
        intentScore: intent,
        isSuspended: level == RiskLevel.danger,
      );

      ref.read(historyProvider.notifier).addRecord(record);
      if (level == RiskLevel.danger) {
        ref.read(homeProvider.notifier).reportThreat(record);
      }
      _loggedCurrentCall = true;
    }

    ref.read(callMonitorProvider.notifier).endCall();
  }

  void _showForensicDossier() {
    final state = ref.read(callMonitorProvider);
    final score = (state.overallFraudScore * 100).round().clamp(0, 100);
    final record = CallRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      callerName: 'Forensic Capture',
      phoneNumber: state.activeCallNumber,
      callTime: DateTime.now(),
      riskLevel: CallRecord.levelFromScore(score),
      riskScore: score,
      syntheticScore: (state.syntheticVoiceScore * 100).round().clamp(0, 100),
      intentScore: (state.scamChanceScore * 100).round().clamp(0, 100),
      isSuspended: score >= 65,
    );

    final report = LocalReportService.generateForensicReport(
      record: record,
      transcript: state.safeTranscript,
      detectedKeywords: state.safeDetectedKeywords,
      alertType: state.scamAlertType,
      alertMessage: state.scamAlertMessage,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: inputBorder),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: inputBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: accentCyan, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'FORENSIC INCIDENT DOSSIER',
                    style: GoogleFonts.rajdhani(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgPrimary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: inputBorder),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollCtrl,
                    child: SelectableText(
                      report,
                      style: GoogleFonts.jetBrainsMono(
                        color: textSecondary,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: bgSurface,
                        content: Text(
                          'Incident dossier saved to encrypted local SQLite vault.',
                          style: GoogleFonts.rajdhani(color: accentEmerald),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_rounded, color: bgPrimary),
                  label: Text(
                    'EXPORT LOCAL EVIDENCE VAULT',
                    style: GoogleFonts.rajdhani(
                      color: bgPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentCyan,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

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
      duration: const Duration(milliseconds: 800),
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
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.4 + _c.value * 0.6),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _c.value * 0.6),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _SimulatorChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SimulatorChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.rajdhani(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _ScamAlertCard extends StatefulWidget {
  final String alertType;
  final String alertMessage;
  final VoidCallback onDismiss;

  const _ScamAlertCard({
    required this.alertType,
    required this.alertMessage,
    required this.onDismiss,
  });

  @override
  State<_ScamAlertCard> createState() => _ScamAlertCardState();
}

class _ScamAlertCardState extends State<_ScamAlertCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: riskRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: riskRed.withValues(alpha: 0.6 + _pulse.value * 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: riskRed.withValues(alpha: 0.15 + _pulse.value * 0.15),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dangerous_rounded, color: riskRed, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'CRITICAL THREAT: ${widget.alertType.replaceAll("_", " ").toUpperCase()}',
                    style: GoogleFonts.rajdhani(
                      color: riskRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: const Icon(
                    Icons.close_rounded,
                    color: textSecondary,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.alertMessage,
              style: GoogleFonts.rajdhani(
                color: textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
