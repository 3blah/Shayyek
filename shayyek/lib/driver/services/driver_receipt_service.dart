import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'driver_task_service.dart';

class DriverReceiptSummary {
  const DriverReceiptSummary({
    required this.sessionId,
    required this.userId,
    required this.lotName,
    required this.lotAddress,
    required this.stallLabel,
    required this.status,
    required this.invoiceType,
    required this.currency,
    required this.ratePerHour,
    required this.billedMinutes,
    required this.timeLimitMinutes,
    required this.totalAmount,
    this.startAt,
    this.endAt,
    this.expireAt,
  });

  final String sessionId;
  final String userId;
  final String lotName;
  final String lotAddress;
  final String stallLabel;
  final String status;
  final String invoiceType;
  final String currency;
  final double ratePerHour;
  final int billedMinutes;
  final int timeLimitMinutes;
  final double totalAmount;
  final String? startAt;
  final String? endAt;
  final String? expireAt;
}

class DriverReceiptService {
  DriverReceiptSummary buildSummary({
    required DriverSession session,
    DriverLot? lot,
    DriverStall? stall,
    DateTime? nowUtc,
  }) {
    final start = _parseDateTime(session.startTime) ??
        _parseDateTime(session.updatedAt) ??
        DateTime.now().toUtc();
    final currentNow = nowUtc ?? DateTime.now().toUtc();
    final end = _parseDateTime(session.endTime) ??
        (session.isCompleted ? _parseDateTime(session.expireAt) : currentNow) ??
        currentNow;

    final diffSeconds = math.max(0, end.difference(start).inSeconds);
    final billedMinutes = math.max(1, (diffSeconds / 60).ceil());
    final ratePerHour = stall?.rateHou ?? lot?.rateHou ?? 0;
    final currency = _nonEmpty(stall?.currency, lot?.currency, 'SAR');
    final timeLimitMinutes = (stall?.maxStay ?? 0) > 0
        ? stall!.maxStay
        : math.max(lot?.maxStay ?? 0, 0);
    final totalAmount = ratePerHour <= 0
        ? 0.0
        : double.parse((ratePerHour * billedMinutes / 60).toStringAsFixed(2));

    return DriverReceiptSummary(
      sessionId: session.id,
      userId: session.userId,
      lotName: lot?.name ?? session.lotId,
      lotAddress: lot?.address ?? '-',
      stallLabel: stall?.label ?? session.stallId,
      status: session.status,
      invoiceType: session.isCompleted ? 'Final invoice' : 'Current invoice',
      currency: currency,
      ratePerHour: ratePerHour,
      billedMinutes: billedMinutes,
      timeLimitMinutes: timeLimitMinutes,
      totalAmount: totalAmount,
      startAt: session.startTime,
      endAt: session.endTime,
      expireAt: session.expireAt,
    );
  }

  DateTime? _parseDateTime(String? value) {
    final clean = (value ?? '').trim();
    if (clean.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(clean).toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<String> shareInvoice({
    required DriverSession session,
    DriverLot? lot,
    DriverStall? stall,
    required bool isArabic,
  }) async {
    final summary = buildSummary(
      session: session,
      lot: lot,
      stall: stall,
    );
    final file = await _buildPdf(summary);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Parking invoice ${summary.sessionId}',
      text: isArabic
          ? 'فاتورة الموقف ${summary.sessionId}'
          : 'Parking invoice ${summary.sessionId}',
    );
    return isArabic
        ? 'تم تجهيز الفاتورة ومشاركتها.'
        : 'The invoice is ready to share.';
  }

  Future<File> _buildPdf(DriverReceiptSummary summary) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Text(
              'Shayyek Parking Invoice',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              summary.invoiceType,
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 14),
            _infoTable(summary),
            pw.SizedBox(height: 18),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Charge summary',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _summaryRow(
                    'Rate per hour',
                    '${summary.ratePerHour.toStringAsFixed(2)} ${summary.currency}',
                  ),
                  _summaryRow(
                    'Billed duration',
                    '${summary.billedMinutes} min',
                  ),
                  _summaryRow(
                    'Time limit',
                    summary.timeLimitMinutes > 0
                        ? '${summary.timeLimitMinutes} min'
                        : '-',
                  ),
                  _summaryRow(
                    'Estimated amount',
                    '${summary.totalAmount.toStringAsFixed(2)} ${summary.currency}',
                    emphasized: true,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Generated from the current parking session data in Firebase Realtime Database.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ];
        },
      ),
    );

    final bytes = await document.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/invoice_${summary.sessionId}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  pw.Widget _infoTable(DriverReceiptSummary summary) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(2.0),
      },
      children: [
        _row('Session id', summary.sessionId),
        _row('User id', summary.userId),
        _row('Lot', summary.lotName),
        _row('Address', summary.lotAddress),
        _row('Stall', summary.stallLabel),
        _row('Status', summary.status),
        _row('Start time', summary.startAt ?? '-'),
        _row('End time', summary.endAt ?? '-'),
        _row('Expiry time', summary.expireAt ?? '-'),
      ],
    );
  }

  pw.TableRow _row(String label, String value) {
    return pw.TableRow(
      children: [
        _cell(
          label,
          bold: true,
          background: PdfColors.grey100,
        ),
        _cell(value),
      ],
    );
  }

  pw.Widget _cell(
    String value, {
    bool bold = false,
    PdfColor? background,
  }) {
    return pw.Container(
      color: background,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _summaryRow(
    String label,
    String value, {
    bool emphasized = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: emphasized ? 13 : 10,
              fontWeight:
                  emphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

String _nonEmpty(String? a, [String? b, String fallback = '']) {
  final first = (a ?? '').trim();
  if (first.isNotEmpty) {
    return first;
  }
  final second = (b ?? '').trim();
  if (second.isNotEmpty) {
    return second;
  }
  return fallback;
}
