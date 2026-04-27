import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../app_text.dart';
import 'admin_theme.dart';

String adminText(BuildContext context, String ar, String en) {
  return AppText.of(context, ar: ar, en: en);
}

Map<String, dynamic> mapOf(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return {};
}

List<MapEntry<String, dynamic>> childEntries(dynamic value) {
  final m = mapOf(value);
  final list = m.entries.toList();
  list.sort((a, b) => a.key.compareTo(b.key));
  return list;
}

int toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

double toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

bool toBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true';
  return false;
}

String s(dynamic v, [String fallback = '-']) {
  if (v == null) return fallback;
  final t = v.toString().trim();
  return t.isEmpty ? fallback : t;
}

String repairDisplayText(String text) {
  final value = text.trim();
  if (value.isEmpty) return value;
  if (!RegExp(r'[ØÙÃÂ]').hasMatch(value)) return value;
  try {
    return utf8.decode(latin1.encode(value), allowMalformed: false);
  } catch (_) {
    return value;
  }
}

String displayText(dynamic v, [String fallback = '-']) {
  return repairDisplayText(s(v, fallback));
}

String f1(dynamic v) => toDouble(v).toStringAsFixed(1);

String dateShort(dynamic v) {
  final raw = s(v, '');
  if (raw.isEmpty) return '-';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  final x = d.toLocal();
  final y = x.year.toString().padLeft(4, '0');
  final m = x.month.toString().padLeft(2, '0');
  final day = x.day.toString().padLeft(2, '0');
  final h = x.hour.toString().padLeft(2, '0');
  final min = x.minute.toString().padLeft(2, '0');
  return '$y-$m-$day  $h:$min';
}

String nowIsoUtc() => DateTime.now().toUtc().toIso8601String();

DateTime? parseIso(dynamic v) {
  final raw = s(v, '');
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

String prettyJson(dynamic v) {
  try {
    return const JsonEncoder.withIndent('  ').convert(v);
  } catch (_) {
    return v.toString();
  }
}

Color uiText(BuildContext c) {
  return Theme.of(c).brightness == Brightness.dark
      ? AdminColors.darkText
      : AdminColors.lightText;
}

Color uiSub(BuildContext c) {
  return Theme.of(c).brightness == Brightness.dark
      ? AdminColors.darkSub
      : AdminColors.lightSub;
}

Color uiBorder(BuildContext c) {
  return Theme.of(c).brightness == Brightness.dark
      ? AdminColors.darkBorder
      : AdminColors.lightBorder;
}

Color uiCard(BuildContext c) {
  return Theme.of(c).brightness == Brightness.dark
      ? AdminColors.darkCard
      : AdminColors.lightCard;
}

Color uiBg(BuildContext c) => Theme.of(c).scaffoldBackgroundColor;

Color statusColor(String status) {
  final x = status.toLowerCase();
  if (x.contains('free') ||
      x.contains('فارغ') ||
      x.contains('online') ||
      x.contains('متصل') ||
      x.contains('sent') ||
      x.contains('مرسل') ||
      x.contains('active') ||
      x.contains('نشط') ||
      x.contains('published') ||
      x.contains('منشور') ||
      x.contains('success')) {
    return AdminColors.success;
  }
  if (x.contains('occupied') ||
      x.contains('مشغول') ||
      x.contains('offline') ||
      x.contains('غير متصل') ||
      x.contains('failed') ||
      x.contains('فشل') ||
      x.contains('rejected') ||
      x.contains('blocked') ||
      x.contains('inactive') ||
      x.contains('غير نشط') ||
      x.contains('danger') ||
      x.contains('error')) {
    return AdminColors.danger;
  }
  if (x.contains('queued') ||
      x.contains('قيد') ||
      x.contains('draft') ||
      x.contains('مسودة') ||
      x.contains('cancelled') ||
      x.contains('ملغي') ||
      x.contains('unknown') ||
      x.contains('غير معروف')) {
    return AdminColors.warning;
  }
  return AdminColors.warning;
}

Widget firebaseBox({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  return Container(
    decoration: BoxDecoration(
      color: uiCard(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: uiBorder(context)),
      boxShadow: [
        BoxShadow(
          blurRadius: 12,
          offset: const Offset(0, 4),
          color: Colors.black.withOpacity(
            Theme.of(context).brightness == Brightness.dark ? .18 : .05,
          ),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: uiText(context),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

Widget loadingBox(BuildContext context) {
  return Container(
    height: 120,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: uiCard(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: uiBorder(context)),
    ),
    child: const CircularProgressIndicator(),
  );
}

Widget errorBox(BuildContext context, VoidCallback onRetry) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: uiCard(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: uiBorder(context)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AdminColors.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            adminText(context, 'تعذر تحميل البيانات', 'Failed to load data'),
            style: TextStyle(
              color: dark ? AdminColors.darkText : AdminColors.lightText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        FilledButton(
          onPressed: onRetry,
          child: Text(adminText(context, 'إعادة المحاولة', 'Retry')),
        ),
      ],
    ),
  );
}

Future<void> showOk(BuildContext context, String title, String msg) async {
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AdminColors.success),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(msg),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(adminText(context, 'موافق', 'OK')),
        ),
      ],
    ),
  );
}

Future<void> showError(BuildContext context, String msg) async {
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AdminColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(adminText(context, 'خطأ', 'Error'))),
        ],
      ),
      content: Text(msg),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(adminText(context, 'موافق', 'OK')),
        ),
      ],
    ),
  );
}

void showSnack(BuildContext context, String msg, {bool isError = false}) {
  final s = ScaffoldMessenger.of(context);
  s.clearSnackBars();
  s.showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AdminColors.danger : null,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmText,
  String? cancelText,
  Color confirmColor = AdminColors.danger,
  IconData icon = Icons.help_outline_rounded,
  Color iconColor = AdminColors.warning,
}) async {
  final resolvedConfirmText =
      confirmText ?? adminText(context, 'تأكيد', 'Confirm');
  final resolvedCancelText =
      cancelText ?? adminText(context, 'إلغاء', 'Cancel');
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(resolvedCancelText),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: confirmColor),
          child: Text(resolvedConfirmText),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String? hint,
  int maxLen = 160,
  bool requiredField = true,
  int minLines = 1,
  int maxLines = 1,
}) async {
  final c = TextEditingController(text: initial);
  final key = GlobalKey<FormState>();

  String? v(String x) {
    final t = x.trim();
    if (requiredField && t.isEmpty) {
      return adminText(context, '$label مطلوب', '$label is required');
    }
    if (t.length > maxLen) {
      return adminText(
          context, 'النص طويل جدًا (الحد $maxLen)', 'Too long (max $maxLen)');
    }
    return null;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: key,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: TextFormField(
            controller: c,
            validator: (x) => v(x ?? ''),
            minLines: minLines,
            maxLines: maxLines,
            decoration: InputDecoration(labelText: label, hintText: hint),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(adminText(context, 'إلغاء', 'Cancel'))),
        FilledButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            if (key.currentState?.validate() != true) return;
            Navigator.pop(context, true);
          },
          child: Text(adminText(context, 'حفظ', 'Save')),
        ),
      ],
    ),
  );

  if (ok != true) return null;
  return c.text.trim();
}

Future<int?> promptInt(
  BuildContext context, {
  required String title,
  required String label,
  required int initial,
  int? min,
  int? max,
}) async {
  final c = TextEditingController(text: '$initial');
  final key = GlobalKey<FormState>();

  String? v(String x) {
    final t = x.trim();
    if (t.isEmpty) {
      return adminText(context, '$label مطلوب', '$label is required');
    }
    final n = int.tryParse(t);
    if (n == null) {
      return adminText(context, 'أدخل رقمًا صحيحًا', 'Enter a valid integer');
    }
    if (min != null && n < min) {
      return adminText(context, 'الحد الأدنى $min', 'Minimum is $min');
    }
    if (max != null && n > max) {
      return adminText(context, 'الحد الأقصى $max', 'Maximum is $max');
    }
    return null;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title),
      content: Form(
        key: key,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: TextFormField(
          controller: c,
          keyboardType: TextInputType.number,
          validator: (x) => v(x ?? ''),
          decoration: InputDecoration(labelText: label),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(adminText(context, 'إلغاء', 'Cancel'))),
        FilledButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            if (key.currentState?.validate() != true) return;
            Navigator.pop(context, true);
          },
          child: Text(adminText(context, 'حفظ', 'Save')),
        ),
      ],
    ),
  );

  if (ok != true) return null;
  return int.tryParse(c.text.trim());
}

Future<double?> promptDouble(
  BuildContext context, {
  required String title,
  required String label,
  required double initial,
  double? min,
  double? max,
  int decimals = 3,
}) async {
  final c = TextEditingController(text: initial.toString());
  final key = GlobalKey<FormState>();

  String? v(String x) {
    final t = x.trim();
    if (t.isEmpty) {
      return adminText(context, '$label مطلوب', '$label is required');
    }
    final n = double.tryParse(t);
    if (n == null) {
      return adminText(context, 'أدخل رقمًا صالحًا', 'Enter a valid number');
    }
    if (min != null && n < min) {
      return adminText(context, 'الحد الأدنى $min', 'Minimum is $min');
    }
    if (max != null && n > max) {
      return adminText(context, 'الحد الأقصى $max', 'Maximum is $max');
    }
    return null;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title),
      content: Form(
        key: key,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: TextFormField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
          validator: (x) => v(x ?? ''),
          decoration: InputDecoration(labelText: label),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(adminText(context, 'إلغاء', 'Cancel'))),
        FilledButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            if (key.currentState?.validate() != true) return;
            Navigator.pop(context, true);
          },
          child: Text(adminText(context, 'حفظ', 'Save')),
        ),
      ],
    ),
  );

  if (ok != true) return null;
  final d = double.tryParse(c.text.trim());
  if (d == null) return null;
  return double.parse(d.toStringAsFixed(decimals));
}

Future<DateTimeRange?> promptDateRange(
  BuildContext context, {
  required String title,
  DateTimeRange? initial,
}) async {
  final now = DateTime.now();
  final first = DateTime(now.year - 2, 1, 1);
  final last = DateTime(now.year + 5, 12, 31);

  final range = await showDateRangePicker(
    context: context,
    firstDate: first,
    lastDate: last,
    initialDateRange: initial,
    helpText: title,
  );

  return range;
}

Future<T?> promptOption<T>(
  BuildContext context, {
  required String title,
  required String label,
  required T initial,
  required List<DropdownMenuItem<T>> items,
}) async {
  T value = initial;

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title),
      content: DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: (v) => value = v ?? value,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(adminText(context, 'إلغاء', 'Cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(adminText(context, 'حفظ', 'Save'))),
      ],
    ),
  );

  if (ok != true) return null;
  return value;
}

Future<void> fbSet(
  BuildContext context, {
  required FirebaseDatabase db,
  required String path,
  required dynamic value,
  String? okTitle,
  String? okMsg,
}) async {
  try {
    await db.ref(path).set(value);
    if (!context.mounted) return;
    await showOk(
      context,
      okTitle ?? adminText(context, 'تم الحفظ', 'Saved'),
      okMsg ?? adminText(context, 'تم التحديث بنجاح', 'Updated successfully'),
    );
  } catch (e) {
    if (!context.mounted) return;
    await showError(context, e.toString());
  }
}

Future<void> fbUpdate(
  BuildContext context, {
  required FirebaseDatabase db,
  required String path,
  required Map<String, dynamic> value,
  String? okTitle,
  String? okMsg,
}) async {
  try {
    await db.ref(path).update(value);
    if (!context.mounted) return;
    await showOk(
      context,
      okTitle ?? adminText(context, 'تم الحفظ', 'Saved'),
      okMsg ?? adminText(context, 'تم التحديث بنجاح', 'Updated successfully'),
    );
  } catch (e) {
    if (!context.mounted) return;
    await showError(context, e.toString());
  }
}

Future<void> fbRemove(
  BuildContext context, {
  required FirebaseDatabase db,
  required String path,
  required String title,
  required String message,
  String okTitle = 'Deleted',
  String okMsg = 'Removed successfully',
}) async {
  final ok = await confirmDialog(
    context,
    title: title,
    message: message,
    confirmText: adminText(context, 'حذف', 'Delete'),
    cancelText: adminText(context, 'إلغاء', 'Cancel'),
    confirmColor: AdminColors.danger,
    icon: Icons.delete_outline_rounded,
    iconColor: AdminColors.danger,
  );
  if (!ok) return;

  try {
    await db.ref(path).remove();
    if (!context.mounted) return;
    await showOk(
      context,
      okTitle == 'Deleted'
          ? adminText(context, 'تم الحذف', 'Deleted')
          : okTitle,
      okMsg == 'Removed successfully'
          ? adminText(context, 'تمت الإزالة بنجاح', 'Removed successfully')
          : okMsg,
    );
  } catch (e) {
    if (!context.mounted) return;
    await showError(context, e.toString());
  }
}

DatabaseReference refPath(FirebaseDatabase db, String path) => db.ref(path);

String? vRequired(String v, String label) =>
    v.trim().isEmpty ? '$label is required' : null;

String? vIdSimple(String v, {String label = 'ID', Set<String>? existing}) {
  final t = v.trim();
  if (t.isEmpty) return '$label is required';
  final ok = RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(t);
  if (!ok) return 'Only letters, numbers, "_" or "-"';
  if (existing != null && existing.contains(t)) return '$label already exists';
  return null;
}

String? vCurrency3(String v) {
  final t = v.trim().toUpperCase();
  if (t.isEmpty) return 'Currency is required';
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(t)) {
    return 'Use 3-letter code (e.g., SAR)';
  }
  return null;
}

String? vLat(String v) {
  final t = v.trim();
  if (t.isEmpty) return 'Latitude is required';
  final d = double.tryParse(t);
  if (d == null) return 'Enter a valid number';
  if (d < -90 || d > 90) return 'Range: -90 to 90';
  return null;
}

String? vLng(String v) {
  final t = v.trim();
  if (t.isEmpty) return 'Longitude is required';
  final d = double.tryParse(t);
  if (d == null) return 'Enter a valid number';
  if (d < -180 || d > 180) return 'Range: -180 to 180';
  return null;
}
