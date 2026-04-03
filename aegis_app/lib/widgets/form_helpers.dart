import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import '../core/colors.dart';

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.rajdhani(
        color: textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }
}

class FieldHint extends StatelessWidget {
  final String text;
  const FieldHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: GoogleFonts.rajdhani(color: textMuted, fontSize: 11),
      ),
    );
  }
}

class PhoneField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const PhoneField({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      initialCountryCode: 'US',
      style: GoogleFonts.rajdhani(color: textPrimary, fontSize: 15),
      dropdownTextStyle: GoogleFonts.rajdhani(color: textPrimary, fontSize: 15),
      dropdownIconPosition: IconPosition.trailing,
      dropdownIcon: const Icon(Icons.arrow_drop_down, color: textSecondary, size: 18),
      decoration: InputDecoration(
        hintText: 'PHONE NUMBER',
        hintStyle: GoogleFonts.rajdhani(color: textMuted, fontSize: 14),
      ),
      onChanged: (phone) => onChanged(phone.completeNumber),
    );
  }
}
