import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';

/// Labelled text-field matching the A.E.G.I.S design system.
class AegisTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixWidget;
  final String? helperText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const AegisTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixWidget,
    this.helperText,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(
            color: textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.rajdhani(color: textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.rajdhani(color: textMuted, fontSize: 14),
            suffixIcon: suffixIcon,
            prefix: prefixWidget != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: prefixWidget,
                  )
                : null,
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: GoogleFonts.rajdhani(color: textMuted, fontSize: 11),
          ),
        ],
      ],
    );
  }
}
