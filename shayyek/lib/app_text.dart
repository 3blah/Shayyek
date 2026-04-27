import 'dart:convert';

import 'package:flutter/material.dart';

import 'theme_controller.dart';

class AppText {
  const AppText._();

  static bool isArabic(BuildContext context) {
    final controller = ThemeScope.maybeOf(context);
    if (controller != null) {
      return controller.effectiveLanguageCode.toLowerCase().startsWith('ar');
    }

    return Localizations.localeOf(context)
        .languageCode
        .toLowerCase()
        .startsWith('ar');
  }

  static String of(
    BuildContext context, {
    required String ar,
    required String en,
  }) {
    return _repairLegacyEncoding(isArabic(context) ? ar : en);
  }

  static String _repairLegacyEncoding(String value) {
    final looksMojibake = RegExp(r'[ØÙÃÂâ]').hasMatch(value);
    if (!looksMojibake) {
      return value;
    }

    try {
      final repaired = utf8.decode(latin1.encode(value));
      if (!repaired.contains('\uFFFD')) {
        return repaired;
      }
    } catch (_) {
      // Keep the original if it was not a Latin-1 mojibake string.
    }

    return value;
  }
}
