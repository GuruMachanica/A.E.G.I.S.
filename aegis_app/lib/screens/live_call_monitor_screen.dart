import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import '../core/colors.dart';
import '../models/call_record.dart';
import '../models/risk_level.dart';
import '../services/backend_service.dart';
import '../providers/auth_provider.dart';
import '../providers/call_monitor_provider.dart';
import '../providers/history_provider.dart';
import '../providers/home_provider.dart';
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
          : 'Unknown';
      ref.read(callMonitorProvider.notifier).startMonitoring(callNumber);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callMonitorProvider);

    // Auto-pop when call is ended
    ref.listen<CallMonitorState>(callMonitorProvider, (prev, next) {
      if (next.callEnded && context.canPop()) context.pop();
      // Trigger haptic when a NEW scam alert appears
      if (next.scamAlertActive &&
          (prev == null || !prev.scamAlertActive || prev.scamAlertType != next.scamAlertType)) {
        Vibration.vibrate(pattern: [0, 400, 200, 400]);
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        ref.read(callMonitorProvider.notifier).endCall();
                      },
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: textSecondary,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Live Monitor',
                      style: GoogleFonts.rajdhani(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    // Recording indicator
                    Row(
                      children: [
                        _PulsingDot(color: riskRed),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: GoogleFonts.rajdhani(
                            color: riskRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // ── Active Call Info ──────────────────────────────────
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentTealDark,
                          border: Border.all(color: accentTealDim, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.phone_rounded,
                          color: accentTeal,
                          size: 28,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Active Call:',
                        style: GoogleFonts.rajdhani(
                          color: textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        state.activeCallNumber,
                        style: GoogleFonts.rajdhani(
                          color: textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: inputBorder),
                        ),
                        child: Text(
                          'Mic Debug: ${state.safeAudioChunksPerSecond} chunks/s '
                          'at ${state.safeRecorderSampleRate > 0 ? state.safeRecorderSampleRate : '--'} Hz',
                          style: GoogleFonts.rajdhani(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (state.errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: riskRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: riskRed.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            state.errorMessage!,
                            style: GoogleFonts.rajdhani(
                              color: riskRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      if (state.isConnecting) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: CircularProgressIndicator(
                            color: accentTeal,
                            strokeWidth: 2.8,
                          ),
                        ),
                        Text(
                          'Connecting to secure analyzer...',
                          style: GoogleFonts.rajdhani(
                            color: textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Main Fraud Gauge ──────────────────────────────────
                      RiskGauge(
                        score: state.overallFraudScore,
                        size: 220,
                        centerLabel:
                            'Overall Fraud\nScore:${(state.overallFraudScore * 100).round()}%',
                        subLabel: state.overallFraudScore >= 0.65
                            ? 'Extremely High Risk\nAssessment'
                            : state.overallFraudScore >= 0.35
                            ? 'Moderate Risk\nAssessment'
                            : 'Low Risk\nAssessment',
                      ),

                      const SizedBox(height: 16),

                      // ── Warning Banner ────────────────────────────────────
                      if (state.showSensitiveAlert) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.notification_important_rounded,
                              color: bgPrimary,
                            ),
                            label: Text(
                              'Sensitive Keyword Detected',
                              style: GoogleFonts.rajdhani(
                                color: bgPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: riskYellow,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Scam Alert Overlay ─────────────────────────────────
                      if (state.scamAlertActive && state.scamAlertMessage != null) ...[
                        _ScamAlertCard(
                          alertType: state.scamAlertType ?? 'unknown',
                          alertMessage: state.scamAlertMessage!,
                          onDismiss: () {
                            ref.read(callMonitorProvider.notifier).dismissScamAlert();
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 240),
                          opacity: state.isHighRisk && !state.isMuted ? 1 : 0,
                          child: state.isHighRisk && !state.isMuted
                              ? _WarningBanner(
                                  syntheticScore: state.syntheticVoiceScore,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (state.safeDetectedKeywords.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Detected Keywords',
                            style: GoogleFonts.rajdhani(
                              color: textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
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
                                    color: riskYellow.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: riskYellow.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    kw.toUpperCase(),
                                    style: GoogleFonts.rajdhani(
                                      color: riskYellow,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                      ],

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: inputBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice-to-Text Transcript',
                              style: GoogleFonts.rajdhani(
                                color: textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              state.safeTranscript.trim().isEmpty
                                  ? 'Listening for speech...'
                                  : state.safeTranscript,
                              style: GoogleFonts.rajdhani(
                                color: textPrimary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _downloadLatestReport,
                                icon: const Icon(
                                  Icons.download_rounded,
                                  color: accentTeal,
                                ),
                                label: Text(
                                  'Download AI Call Report (PDF)',
                                  style: GoogleFonts.rajdhani(
                                    color: accentTeal,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Sub Gauges ────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _SubGaugeCard(
                              score: state.syntheticVoiceScore,
                              label:
                                  'Synthetic Voice\nScore:${(state.syntheticVoiceScore * 100).round()}%',
                              subLabel: state.syntheticVoiceScore >= 0.65
                                  ? 'Artificial speech\nprobability:High'
                                  : 'Artificial speech\nprobability:Low',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _SubGaugeCard(
                              score: state.scamChanceScore,
                              label:
                                  'Scam Chance\nScore:${(state.scamChanceScore * 100).round()}%',
                              subLabel: state.scamChanceScore >= 0.65
                                  ? '"Contextual risk\nassessment:Urgent"'
                                  : '"Contextual risk\nassessment:Low"',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),

              // ── Action Bar ─────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: bgSurface,
                  border: Border(
                    top: BorderSide(color: inputBorder, width: 0.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionButton(
                        icon: state.isMuted
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        label: 'Mute Alert',
                        color: state.isMuted ? accentTeal : textSecondary,
                        onTap: () {
                          ref.read(callMonitorProvider.notifier).muteAlert();
                        },
                      ),
                      _ActionButton(
                        icon: Icons.call_end_rounded,
                        label: 'End Call',
                        color: riskRed,
                        onTap: _endCallAndLog,
                      ),
                      _ActionButton(
                        icon: state.isFlagged
                            ? Icons.flag_rounded
                            : Icons.flag_outlined,
                        label: 'Flag Call',
                        color: state.isFlagged ? riskYellow : textSecondary,
                        onTap: () {
                          ref.read(callMonitorProvider.notifier).flagCall();
                        },
                      ),
                    ],
                  ),
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
      final synthetic = (monitor.syntheticVoiceScore * 100).round().clamp(
        0,
        100,
      );
      final intent = (monitor.scamChanceScore * 100).round().clamp(0, 100);
      final level = CallRecord.levelFromScore(score);

      final record = CallRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        callerName: 'Live Call Scan',
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

  Future<void> _downloadLatestReport() async {
    final url = ref
        .read(backendServiceProvider)
        .latestAiReportPdfUrl()
        .toString();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: bgSurface,
          content: Text(
            'Unable to download PDF report.',
            style: GoogleFonts.rajdhani(color: riskYellow),
          ),
        ),
      );
    }
  }
}

// ── Warning Banner ─────────────────────────────────────────────────────────────
class _WarningBanner extends StatelessWidget {
  final double syntheticScore;
  const _WarningBanner({required this.syntheticScore});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: riskYellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: riskYellow.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: riskYellow, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'WARNING: HIGH SCAM PROBABILITY\n(Deepfake Voice Detected, Financial Urgency)',
              style: GoogleFonts.rajdhani(
                color: riskYellow,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub Gauge Card ─────────────────────────────────────────────────────────────
class _SubGaugeCard extends StatelessWidget {
  final double score;
  final String label;
  final String subLabel;
  const _SubGaugeCard({
    required this.score,
    required this.label,
    required this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: inputBorder, width: 0.8),
      ),
      child: Column(
        children: [
          RiskGauge(
            score: score,
            size: 130,
            centerLabel: label,
            subLabel: subLabel,
          ),
        ],
      ),
    );
  }
}

// ── Action Button ──────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing Dot ────────────────────────────────────────────────────────────────
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
          color: widget.color.withValues(alpha: 0.5 + _c.value * 0.5),
        ),
      ),
    );
  }
}

// ── Scam Alert Card ────────────────────────────────────────────────────────────────────
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
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'otp_asked':
        return Icons.password_rounded;
      case 'money_asked':
        return Icons.currency_rupee_rounded;
      case 'kyc_scam':
        return Icons.verified_user_outlined;
      case 'bank_details_asked':
        return Icons.account_balance_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  String _titleForType(String type) {
    switch (type) {
      case 'otp_asked':
        return 'OTP / PIN SCAM DETECTED';
      case 'money_asked':
        return 'MONEY DEMAND DETECTED';
      case 'kyc_scam':
        return 'FAKE KYC SCAM DETECTED';
      case 'bank_details_asked':
        return 'BANK DETAILS SCAM DETECTED';
      default:
        return 'SCAM ALERT';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final borderAlpha = 0.6 + _pulseCtrl.value * 0.4;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: riskRed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: riskRed.withValues(alpha: borderAlpha),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: riskRed.withValues(alpha: 0.15 + _pulseCtrl.value * 0.1),
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
                  Icon(
                    _iconForType(widget.alertType),
                    color: riskRed,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _titleForType(widget.alertType),
                      style: GoogleFonts.rajdhani(
                        color: riskRed,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.alertMessage,
                style: GoogleFonts.rajdhani(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onDismiss,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: riskRed.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'DISMISS ALERT',
                    style: GoogleFonts.rajdhani(
                      color: riskRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
