import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../app_text.dart';
import '../services/driver_task_service.dart';
import '../ui/driver_palette.dart';
import '../ui/driver_shared_widgets.dart';

class DriverSessionsPage extends StatelessWidget {
  const DriverSessionsPage({
    super.key,
    required this.now,
    required this.activeSession,
    required this.navigatingSession,
    required this.completedSessions,
    required this.lotNameOf,
    required this.lotAddressOf,
    required this.stallLabelOf,
    required this.onRefresh,
    required this.onConfirmParking,
    required this.onEndSession,
    required this.onSaveParkedPin,
    required this.onShareInvoice,
    this.errorText,
  });

  final DateTime now;
  final DriverSession? activeSession;
  final DriverSession? navigatingSession;
  final List<DriverSession> completedSessions;
  final String Function(String lotId) lotNameOf;
  final String Function(String lotId) lotAddressOf;
  final String Function(String stallId) stallLabelOf;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onConfirmParking;
  final Future<void> Function() onEndSession;
  final Future<void> Function() onSaveParkedPin;
  final Future<void> Function(DriverSession session) onShareInvoice;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          DriverTopHeader(
            title: AppText.of(
              context,
              ar: 'الحجوزات والجلسات',
              en: 'Bookings and sessions',
            ),
            subtitle: AppText.of(
              context,
              ar: 'هنا يظهر الحجز الحالي، الجلسة النشطة، والسجل مع الفاتورة القابلة للمشاركة.',
              en: 'View the current booking, active session, and invoice-ready history here.',
            ),
            icon: Icons.timer_rounded,
          ),
          if (errorText != null) ...[
            const SizedBox(height: 14),
            DriverInfoCard(
              title:
                  AppText.of(context, ar: 'تنبيه جلسات', en: 'Session alert'),
              body: errorText!,
              icon: Icons.error_outline_rounded,
              color: palette.occupied,
            ),
          ],
          const SizedBox(height: 18),
          DriverSectionTitle(
            AppText.of(context, ar: 'الحالة الحالية', en: 'Current status'),
          ),
          const SizedBox(height: 10),
          if (navigatingSession != null)
            _SessionCard(
              session: navigatingSession!,
              title: AppText.of(
                context,
                ar: 'حجز قائم بانتظار الدفع وبدء الوقوف',
                en: 'Booking waiting for payment and activation',
              ),
              subtitle:
                  '${lotNameOf(navigatingSession!.lotId)} • ${stallLabelOf(navigatingSession!.targetStallId)}',
              accent: palette.secondary,
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (navigatingSession!.paymentRatePerMinute != null)
                    DriverInfoCard(
                      title: AppText.of(
                        context,
                        ar: 'دفعة تفعيل الحجز',
                        en: 'Booking activation payment',
                      ),
                      body: AppText.of(
                        context,
                        ar: 'سعر الدقيقة: ${navigatingSession!.paymentRatePerMinute!.toStringAsFixed(2)} ${navigatingSession!.paymentCurrency ?? ''}\n'
                            'المطلوب الآن: ${(navigatingSession!.paymentAmountDueNow ?? navigatingSession!.paymentRatePerMinute ?? 0).toStringAsFixed(2)} ${navigatingSession!.paymentCurrency ?? ''}',
                        en: 'Per-minute rate: ${navigatingSession!.paymentRatePerMinute!.toStringAsFixed(2)} ${navigatingSession!.paymentCurrency ?? ''}\n'
                            'Due now: ${(navigatingSession!.paymentAmountDueNow ?? navigatingSession!.paymentRatePerMinute ?? 0).toStringAsFixed(2)} ${navigatingSession!.paymentCurrency ?? ''}',
                      ),
                      icon: Icons.payments_outlined,
                      color: palette.secondary,
                    ),
                  if (navigatingSession!.paymentRatePerMinute != null)
                    const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onConfirmParking,
                    child: Text(
                      AppText.of(
                        context,
                        ar: 'ادفع وابدأ الجلسة',
                        en: 'Pay and start session',
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (activeSession != null)
            _SessionCard(
              session: activeSession!,
              title: AppText.of(
                context,
                ar: 'جلسة وقوف نشطة',
                en: 'Active parking session',
              ),
              subtitle:
                  '${lotNameOf(activeSession!.lotId)} • ${stallLabelOf(activeSession!.stallId)}',
              accent: palette.available,
              trailing: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DriverActiveSessionDetailsPage(
                              session: activeSession!,
                              now: now,
                              lotName: lotNameOf(activeSession!.lotId),
                              lotAddress: lotAddressOf(activeSession!.lotId),
                              stallLabel: stallLabelOf(activeSession!.stallId),
                              onSaveParkedPin: onSaveParkedPin,
                              onEndSession: onEndSession,
                              onShareInvoice: () =>
                                  onShareInvoice(activeSession!),
                            ),
                          ),
                        );
                      },
                      child: Text(
                        AppText.of(context,
                            ar: 'عرض التفاصيل', en: 'View details'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onEndSession,
                      child: Text(
                        AppText.of(context,
                            ar: 'إنهاء الجلسة', en: 'End session'),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            DriverEmptyState(
              title: AppText.of(context,
                  ar: 'لا توجد جلسة حالية', en: 'No current session'),
              body: AppText.of(
                context,
                ar: 'عند اختيار موقف وبدء الملاحة ثم الدفع، ستظهر الجلسة هنا.',
                en: 'After selecting a stall, navigating, and paying, the session will appear here.',
              ),
              icon: Icons.timer_outlined,
            ),
          const SizedBox(height: 18),
          DriverSectionTitle(
            AppText.of(context, ar: 'السجل', en: 'History'),
          ),
          const SizedBox(height: 10),
          if (completedSessions.isEmpty)
            DriverEmptyState(
              title: AppText.of(context,
                  ar: 'لا يوجد سجل بعد', en: 'No history yet'),
              body: AppText.of(
                context,
                ar: 'الجلسات المكتملة ستظهر هنا بعد الإنهاء.',
                en: 'Completed sessions will appear here after ending them.',
              ),
              icon: Icons.history_rounded,
            )
          else
            ...completedSessions.map(
              (session) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HistoryRow(
                  session: session,
                  lotName: lotNameOf(session.lotId),
                  stallLabel: stallLabelOf(session.stallId),
                  onShareInvoice: () => onShareInvoice(session),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DriverActiveSessionDetailsPage extends StatelessWidget {
  const DriverActiveSessionDetailsPage({
    super.key,
    required this.session,
    required this.now,
    required this.lotName,
    required this.lotAddress,
    required this.stallLabel,
    required this.onSaveParkedPin,
    required this.onEndSession,
    required this.onShareInvoice,
  });

  final DriverSession session;
  final DateTime now;
  final String lotName;
  final String lotAddress;
  final String stallLabel;
  final Future<void> Function() onSaveParkedPin;
  final Future<void> Function() onEndSession;
  final Future<void> Function() onShareInvoice;

  String _remainingText() {
    final expire = DriverTaskService(FirebaseDatabase.instance)
        .parseDateTime(session.expireAt);
    if (expire == null) {
      return '-';
    }
    final difference = expire.difference(now);
    if (difference.isNegative) {
      return 'انتهى';
    }
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    return Scaffold(
      backgroundColor: palette.pageBg,
      appBar: AppBar(
        title: Text(
          AppText.of(context, ar: 'تفاصيل الجلسة', en: 'Session details'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DriverInfoCard(
            title: lotName,
            body: '$lotAddress\n'
                '${AppText.of(context, ar: 'الفراغ', en: 'Stall')}: $stallLabel\n'
                '${AppText.of(context, ar: 'البداية', en: 'Start')}: ${session.startTime ?? '-'}\n'
                '${AppText.of(context, ar: 'الانتهاء', en: 'Expiry')}: ${session.expireAt ?? '-'}\n'
                '${AppText.of(context, ar: 'الوقت المتبقي', en: 'Remaining')}: ${_remainingText()}',
            icon: Icons.local_parking_rounded,
            color: palette.available,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                DriverLabelValue(
                  label: AppText.of(context,
                      ar: 'حالة التذكير', en: 'Reminder status'),
                  value: session.timeAlertSent
                      ? AppText.of(context, ar: 'تم الإرسال', en: 'Sent')
                      : AppText.of(context,
                          ar: 'لم يُرسل بعد', en: 'Not sent yet'),
                ),
                const SizedBox(height: 10),
                DriverLabelValue(
                  label: AppText.of(context,
                      ar: 'إعادة التوجيه', en: 'Auto reroute'),
                  value: session.navAutoReroute
                      ? AppText.of(context, ar: 'مفعلة', en: 'Enabled')
                      : AppText.of(context, ar: 'غير مفعلة', en: 'Disabled'),
                ),
                const SizedBox(height: 10),
                DriverLabelValue(
                  label: AppText.of(context,
                      ar: 'الهدف الحالي', en: 'Current target'),
                  value: session.targetStallId,
                ),
                const SizedBox(height: 10),
                DriverLabelValue(
                  label: AppText.of(context, ar: 'الدفع', en: 'Payment'),
                  value: session.paymentStatus == null
                      ? '-'
                      : '${session.paymentStatus} • ${(session.paymentAmountPaid ?? session.paymentAmountDueNow ?? 0).toStringAsFixed(2)} ${session.paymentCurrency ?? ''}',
                ),
                const SizedBox(height: 10),
                DriverLabelValue(
                  label: 'where_i_parked_pin',
                  value: session.parkedLat != null && session.parkedLong != null
                      ? '${session.parkedLat}, ${session.parkedLong}\n${session.parkedSavedAt ?? ''}'
                      : AppText.of(context, ar: 'غير محفوظ', en: 'Not saved'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onSaveParkedPin,
            icon: const Icon(Icons.push_pin_outlined),
            label: Text(
              AppText.of(
                context,
                ar: 'حفظ أو تحديث موقع السيارة',
                en: 'Save or update parked pin',
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onShareInvoice,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              AppText.of(
                context,
                ar: 'فاتورة PDF / طباعة',
                en: 'Invoice PDF / Print',
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onEndSession,
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(
              AppText.of(context, ar: 'إنهاء الجلسة', en: 'End session'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.trailing,
  });

  final DriverSession session;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DriverPill(
            text: _sessionStatusLabel(context, session.status),
            color: accent,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: palette.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          DriverLabelValue(
            label: AppText.of(context, ar: 'البداية', en: 'Start'),
            value: session.startTime ?? '-',
          ),
          const SizedBox(height: 8),
          DriverLabelValue(
            label: AppText.of(context, ar: 'الانتهاء', en: 'Expiry'),
            value: session.expireAt ?? '-',
          ),
          const SizedBox(height: 14),
          trailing,
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.session,
    required this.lotName,
    required this.stallLabel,
    required this.onShareInvoice,
  });

  final DriverSession session;
  final String lotName;
  final String stallLabel;
  final Future<void> Function() onShareInvoice;

  @override
  Widget build(BuildContext context) {
    final palette = DriverPalette.of(
      Theme.of(context).brightness == Brightness.dark,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lotName,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$stallLabel • ${_sessionStatusLabel(context, session.status)}',
            style: TextStyle(
              color: palette.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppText.of(
              context,
              ar: 'من ${session.startTime ?? '-'} إلى ${session.endTime ?? session.expireAt ?? '-'}',
              en: 'From ${session.startTime ?? '-'} to ${session.endTime ?? session.expireAt ?? '-'}',
            ),
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 8),
          if (session.paymentAmountPaid != null)
            Text(
              AppText.of(
                context,
                ar: 'المدفوع: ${session.paymentAmountPaid!.toStringAsFixed(2)} ${session.paymentCurrency ?? ''}',
                en: 'Paid: ${session.paymentAmountPaid!.toStringAsFixed(2)} ${session.paymentCurrency ?? ''}',
              ),
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12.5,
              ),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: onShareInvoice,
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(
                AppText.of(
                  context,
                  ar: 'فاتورة PDF / طباعة',
                  en: 'Invoice PDF / Print',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _sessionStatusLabel(BuildContext context, String status) {
  switch (status) {
    case 'active':
      return AppText.of(context, ar: 'نشطة', en: 'Active');
    case 'navigating':
      return AppText.of(context, ar: 'ملاحة', en: 'Navigating');
    case 'completed':
      return AppText.of(context, ar: 'مكتملة', en: 'Completed');
    default:
      return status;
  }
}
