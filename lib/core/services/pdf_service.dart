import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../student_id_display.dart';
import '../../shared/models/course_model.dart';
import '../../shared/models/payment_model.dart';
import '../../shared/models/user_model.dart';

// ─── Institution constants ───────────────────────────────────────────────────
const String kInstitutionName      = 'Radiance';
const String kInstitutionTagline   = 'Academic Guidence & Admission Support';
const String kInstitutionAddress   =
    'Ovijan 56, SSAC Road, Auchpara, Tongi, Gazipur';
const String kInstitutionContact   = '01406-751374';

// ─── Monochrome palette (printer-friendly) ────────────────────────────────────
const PdfColor _ink    = PdfColors.black;
const PdfColor _muted  = PdfColor(0.35, 0.35, 0.35);
const PdfColor _hair   = PdfColor(0.78, 0.78, 0.78);

/// Shared PDF font bundle — loaded once per export.
class _PdfFonts {
  _PdfFonts({
    required this.sans,
    required this.sansMedium,
    required this.sansBold,
  });

  final pw.Font sans;
  final pw.Font sansMedium;
  final pw.Font sansBold;

  pw.ThemeData buildTheme() => pw.ThemeData.withFont(
        base: sans,
        bold: sansBold,
        italic: sans,
        boldItalic: sansBold,
      );
}

Future<_PdfFonts> _loadFonts() async {
  // Poppins via Google Fonts — fetched/cached by the printing package.
  final sans       = await PdfGoogleFonts.poppinsRegular();
  final sansMedium = await PdfGoogleFonts.poppinsMedium();
  final sansBold   = await PdfGoogleFonts.poppinsBold();
  return _PdfFonts(sans: sans, sansMedium: sansMedium, sansBold: sansBold);
}

/// Generates printable PDF documents (payment vouchers).
/// Minimalist, monochrome, printer-friendly A5 — Poppins, Latin only.
class PdfService {
  PdfService();

  /// Generates a minimalist black & white A5 payment voucher as PDF bytes.
  ///
  /// Backward-compatible signature: [logoBytes], [institutionAddress],
  /// [institutionPhone], [footerNote] are accepted but the minimalist design
  /// uses the hardcoded institution header by default.
  Future<Uint8List> generateVoucherPdf(
    PaymentModel payment,
    UserModel student,
    CourseModel course, {
    String? serviceName,
    List<PaymentVoucherLineItem>? lineItems,
    bool hideMainVoucherNo = false,
    Uint8List? logoBytes, // accepted for API compat; not rendered
    String? institutionAddress,
    String? institutionPhone,
    String? footerNote,
    String? batchName,
    String? guardianName,
  }) async {
    final fonts = await _loadFonts();

    final paidDate   = payment.paidAt ?? DateTime.now();
    final monthLabel = lineItems != null && lineItems.isNotEmpty
        ? _buildMonthSummary(lineItems)
        : _fmtMonth(payment.forMonth);
    final method     = payment.paymentMethod?.name ?? '—';
    final total      = payment.amount;
    final inWords    = _amountInWordsTaka(total);
    final svc = _formatServiceLabel(serviceName, payment.forMonth);

    final displayName = _pickLatinName(student);

    final address = (institutionAddress?.trim().isNotEmpty ?? false)
        ? institutionAddress!.trim()
        : kInstitutionAddress;
    final phone   = (institutionPhone?.trim().isNotEmpty ?? false)
        ? institutionPhone!.trim()
        : kInstitutionContact;

    final qrPayload = _buildPaymentQrPayload(payment);
    final doc = pw.Document(theme: fonts.buildTheme());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _buildHeader(fonts, address: address, phone: phone),
            pw.SizedBox(height: 16),
            _buildTitleRow(
              fonts,
              hideMainVoucherNo ? '' : payment.voucherNo,
              paidDate,
            ),
            pw.SizedBox(height: 14),
            _buildInfoGrid(
              fonts,
              studentName: displayName,
              studentId: displayStudentIdForUser(student),
              studentPhone: student.phone,
              guardianName: guardianName,
              batchName: batchName,
              courseName: _latinOnly(course.name, fallback: 'Course'),
              serviceName: svc,
              billingMonth: monthLabel,
              method: method,
            ),
            pw.SizedBox(height: 14),
            _buildAmountTable(
              fonts,
              payment,
              total,
              inWords,
              serviceName: svc,
              lineItems: lineItems,
            ),
            if (payment.note?.trim().isNotEmpty ?? false) ...[
              pw.SizedBox(height: 12),
              _buildNoteBox(fonts, _latinOnly(payment.note, fallback: '')),
            ],
            pw.Spacer(),
            _buildSignatureAndQr(fonts, qrPayload),
            pw.SizedBox(height: 10),
            _buildFooter(fonts, footerNote),
          ],
        ),
      ),
    );

    return doc.save();
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

pw.Widget _buildHeader(
  _PdfFonts f, {
  required String address,
  required String phone,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  kInstitutionName.toUpperCase(),
                  style: pw.TextStyle(
                    font: f.sansBold,
                    fontSize: 22,
                    letterSpacing: 3,
                    color: _ink,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  kInstitutionTagline,
                  style: pw.TextStyle(
                    font: f.sans,
                    fontSize: 9,
                    letterSpacing: 2,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'SSC/Dakhil & HSC/Alim',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: f.sansMedium,
                  fontSize: 8,
                  color: _ink,
                ),
              ),
              pw.Text(
                'Academic & Admission',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: f.sansMedium,
                  fontSize: 8,
                  color: _ink,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                address,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  font: f.sans,
                  fontSize: 7.5,
                  color: _muted,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Contact  $phone',
                style: pw.TextStyle(
                  font: f.sansMedium,
                  fontSize: 7.5,
                  color: _ink,
                ),
              ),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Container(height: 0.8, color: _ink),
      pw.SizedBox(height: 1.5),
      pw.Container(height: 0.4, color: _ink),
    ],
  );
}

// ─── Title row ───────────────────────────────────────────────────────────────

pw.Widget _buildTitleRow(_PdfFonts f, String voucherNo, DateTime date) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'PAYMENT RECEIPT',
              style: pw.TextStyle(
                font: f.sansBold,
                fontSize: 14,
                letterSpacing: 4,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Issued upon receipt of payment',
              style: pw.TextStyle(
                font: f.sans,
                fontSize: 8,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _metaLine(f, 'Voucher', voucherNo, valueColor: PdfColors.red700),
          pw.SizedBox(height: 2),
          _metaLine(f, 'Date', _fmtDate(date)),
        ],
      ),
    ],
  );
}

pw.Widget _metaLine(
  _PdfFonts f,
  String label,
  String value, {
  PdfColor valueColor = _ink,
}) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text(
        '${label.toUpperCase()}  ',
        style: pw.TextStyle(
          font: f.sans,
          fontSize: 7,
          letterSpacing: 1.5,
          color: _muted,
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          font: f.sansBold,
          fontSize: 10,
          color: valueColor,
        ),
      ),
    ],
  );
}

// ─── Info grid ───────────────────────────────────────────────────────────────

pw.Widget _buildInfoGrid(
  _PdfFonts f, {
  required String studentName,
  required String studentId,
  required String studentPhone,
  required String? guardianName,
  required String? batchName,
  required String courseName,
  required String serviceName,
  required String billingMonth,
  required String method,
}) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: _sectionBlock(
          f,
          title: 'Bill To',
          children: [
            _kv(f, 'Name', studentName),
            _kv(f, 'Student ID', studentId),
            _kv(f, 'Phone', studentPhone),
            if (guardianName?.trim().isNotEmpty ?? false)
              _kv(f, 'Guardian', guardianName!.trim()),
            if (batchName?.trim().isNotEmpty ?? false)
              _kv(f, 'Batch', batchName!.trim()),
          ],
        ),
      ),
      pw.SizedBox(width: 16),
      pw.Expanded(
        child: _sectionBlock(
          f,
          title: 'Payment Details',
          children: [
            _kv(f, 'Course', courseName),
            _kv(f, 'Service', serviceName),
            _kv(f, 'Billing Month', billingMonth),
            _kv(f, 'Method', method),
            _kv(f, 'Status', 'PAID'),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _sectionBlock(
  _PdfFonts f, {
  required String title,
  required List<pw.Widget> children,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          font: f.sansBold,
          fontSize: 7.5,
          letterSpacing: 2,
          color: _ink,
        ),
      ),
      pw.SizedBox(height: 3),
      pw.Container(height: 0.6, color: _ink),
      pw.SizedBox(height: 6),
      ...children,
    ],
  );
}

pw.Widget _kv(_PdfFonts f, String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 70,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: f.sans,
              fontSize: 8,
              color: _muted,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: f.sansMedium,
              fontSize: 9,
              color: _ink,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Amount table ────────────────────────────────────────────────────────────

pw.Widget _buildAmountTable(
  _PdfFonts f,
  PaymentModel payment,
  double total,
  String words,
  {
  required String serviceName,
  List<PaymentVoucherLineItem>? lineItems,
}
) {
  final rows = (lineItems == null || lineItems.isEmpty)
      ? <PaymentVoucherLineItem>[
          PaymentVoucherLineItem(
            serial: 1,
            serviceName: serviceName,
            month: payment.forMonth,
            amount: payment.amount,
            discount: payment.discount,
            serviceCharge: (total - (payment.subtotal - payment.discount)).clamp(0, 999999999).toDouble(),
            voucherNo: payment.voucherNo,
          ),
        ]
      : lineItems;
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _ink, width: 0.6),
    ),
    child: pw.Column(
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: _ink, width: 0.35),
          columnWidths: const {
            0: pw.FixedColumnWidth(28),
            1: pw.FlexColumnWidth(2.2),
            2: pw.FlexColumnWidth(1.8),
            3: pw.FixedColumnWidth(48),
            4: pw.FixedColumnWidth(48),
            5: pw.FixedColumnWidth(52),
          },
          children: [
            _memoHeaderRow(f),
            ...rows.map(
              (r) => _memoItemRow(
                f,
                slNo: '${r.serial}',
                feeName: _formatServiceLabel(r.serviceName, r.month ?? payment.forMonth),
                voucherNo: _latinOnly(r.voucherNo, fallback: '-'),
                amount: _money(r.amount),
                discount: _money(r.discount),
                serviceCharge: _money(r.serviceCharge),
              ),
            ),
          ],
        ),
        // Total row — double-line top border for emphasis, no fill (printer friendly)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: _ink, width: 0.6),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TOTAL PAID',
                style: pw.TextStyle(
                  font: f.sansBold,
                  fontSize: 10,
                  letterSpacing: 3,
                  color: _ink,
                ),
              ),
              pw.Text(
                _money(total),
                style: pw.TextStyle(
                  font: f.sansBold,
                  fontSize: 14,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
        // Separator (thin + hairline — double-rule look, no fill)
        pw.Container(height: 0.4, color: _ink),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'In Words:  ',
                  style: pw.TextStyle(
                    font: f.sansBold,
                    fontSize: 7.5,
                    letterSpacing: 1.5,
                    color: _muted,
                  ),
                ),
                pw.TextSpan(
                  text: words,
                  style: pw.TextStyle(
                    font: f.sansMedium,
                    fontSize: 8.5,
                    color: PdfColors.red800,
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

pw.TableRow _memoHeaderRow(_PdfFonts f) {
  pw.Widget h(String text, {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: f.sansBold,
            fontSize: 7,
            letterSpacing: 0.7,
            color: _ink,
          ),
        ),
      );
  return pw.TableRow(
    children: [
      h('SL', align: pw.Alignment.center),
      h('SERVICE NAME'),
      h('VOUCHER NO'),
      h('AMOUNT', align: pw.Alignment.centerRight),
      h('DISCOUNT', align: pw.Alignment.centerRight),
      h('SERVICE CHARGE', align: pw.Alignment.centerRight),
    ],
  );
}

pw.TableRow _memoItemRow(
  _PdfFonts f, {
  required String slNo,
  required String feeName,
  required String voucherNo,
  required String amount,
  required String discount,
  required String serviceCharge,
}) {
  pw.Widget c(String text, {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: pw.Text(
          text,
          style: pw.TextStyle(font: f.sansMedium, fontSize: 8.4, color: _ink),
          maxLines: 2,
        ),
      );
  return pw.TableRow(
    children: [
      c(slNo, align: pw.Alignment.center),
      c(_latinOnly(feeName, fallback: 'Payment')),
      c(voucherNo),
      c(amount, align: pw.Alignment.centerRight),
      c(discount, align: pw.Alignment.centerRight),
      c(serviceCharge, align: pw.Alignment.centerRight),
    ],
  );
}

// ─── Note box ────────────────────────────────────────────────────────────────

pw.Widget _buildNoteBox(_PdfFonts f, String note) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(left: pw.BorderSide(color: _ink, width: 2)),
    ),
    padding: const pw.EdgeInsets.fromLTRB(10, 4, 10, 4),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: 'Note  ',
            style: pw.TextStyle(
              font: f.sansBold,
              fontSize: 7.5,
              letterSpacing: 1.5,
              color: _muted,
            ),
          ),
          pw.TextSpan(
            text: note,
            style: pw.TextStyle(
              font: f.sans,
              fontSize: 8.5,
              color: _ink,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Signatures ──────────────────────────────────────────────────────────────

pw.Widget _buildSignatureAndQr(_PdfFonts f, String qrPayload) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Expanded(
        child: pw.Row(
          children: [
            _sigBlock(f, "Student's Signature"),
            pw.SizedBox(width: 24),
            _sigBlock(f, 'Authorized Signature & Stamp'),
          ],
        ),
      ),
      pw.SizedBox(width: 14),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 54,
            height: 54,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _ink, width: 0.5),
            ),
            padding: const pw.EdgeInsets.all(3),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrPayload,
              drawText: false,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Scan to verify',
            style: pw.TextStyle(font: f.sans, fontSize: 6.5, color: _muted),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _sigBlock(_PdfFonts f, String label) {
  return pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 26),
        pw.Container(height: 0.5, color: _ink),
        pw.SizedBox(height: 3),
        pw.Text(
          label,
          style: pw.TextStyle(
            font: f.sans,
            fontSize: 7.5,
            color: _muted,
          ),
        ),
      ],
    ),
  );
}

// ─── Footer ──────────────────────────────────────────────────────────────────

pw.Widget _buildFooter(_PdfFonts f, String? note) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(height: 0.4, color: _hair),
      pw.SizedBox(height: 6),
      pw.Text(
        note ??
            'Thank you for choosing Radiance Coaching Center.  '
                'This is a computer-generated receipt and does not require a wet signature.',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: f.sans,
          fontSize: 7,
          color: _muted,
        ),
      ),
    ],
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Latin-only money format. Uses "Tk" to stay within Poppins glyph coverage.
String _money(double v) => 'Tk ${v.toStringAsFixed(2)}';

/// Picks a Latin-script display name for the student.
/// Falls back to a generic label if no English name is available so that
/// non-Latin glyphs never appear on the voucher.
String _pickLatinName(UserModel u) {
  final en = u.fullNameEn?.trim();
  if (en != null && en.isNotEmpty) return en;
  final id = u.studentId?.trim();
  if (id != null && id.isNotEmpty) return 'Student $id';
  return 'Student';
}

/// Removes non-Latin glyphs to prevent missing glyph warnings in PDF output.
String _latinOnly(String? value, {String fallback = '-'}) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return fallback;
  final cleaned = raw
      .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned.isEmpty ? fallback : cleaned;
}

String _formatServiceLabel(String? serviceName, DateTime forMonth) {
  final raw = _latinOnly(serviceName, fallback: 'Payment').toLowerCase();
  if (raw == 'monthly' || raw == 'monthly_fee' || raw == 'tuition') {
    final m = _monthTag(forMonth);
    return 'Monthly Fee($m)';
  }
  return _toTitleCase(raw);
}

String _buildMonthSummary(List<PaymentVoucherLineItem> items) {
  final months = items
      .map((e) => e.month)
      .whereType<DateTime>()
      .map((d) => DateTime(d.year, d.month, 1))
      .toSet()
      .toList()
    ..sort((a, b) => a.compareTo(b));
  if (months.isEmpty) return '-';
  if (months.length == 1) return _fmtMonth(months.first);
  return '${_fmtMonth(months.first)} - ${_fmtMonth(months.last)}';
}

class PaymentVoucherLineItem {
  const PaymentVoucherLineItem({
    required this.serial,
    required this.serviceName,
    required this.month,
    required this.amount,
    required this.discount,
    required this.serviceCharge,
    this.voucherNo = '',
  });

  final int serial;
  final String serviceName;
  final DateTime? month;
  final double amount;
  final double discount;
  final double serviceCharge;
  final String voucherNo;

  double get netTotal => amount - discount + serviceCharge;
}

String _buildPaymentQrPayload(PaymentModel p) {
  // Temporary behavior: scanning QR shows only voucher number.
  final voucher = p.voucherNo.trim();
  return voucher.isEmpty ? p.id : voucher;
}

String _monthTag(DateTime d) {
  const names = [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ];
  return '${names[d.month - 1]}-${d.year}';
}

String _toTitleCase(String raw) {
  final parts = raw.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return raw;
  return parts
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

String _fmtDate(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/'
      '${l.month.toString().padLeft(2, '0')}/'
      '${l.year}';
}

String _fmtMonth(DateTime m) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${names[m.month - 1]} ${m.year}';
}

String _amountInWordsTaka(double amount) {
  if (amount < 0) return 'Invalid amount';
  final whole = amount.floor();
  final frac  = ((amount - whole) * 100).round() % 100;
  final w     = _toWords(whole);
  if (frac == 0) return 'Taka $w Only';
  return 'Taka $w and ${_toWords(frac)} Paisa Only';
}

String _toWords(int n) {
  if (n == 0) return 'Zero';
  if (n < 0)  return 'Minus ${_toWords(-n)}';
  const u = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven',
    'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen',
    'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
  ];
  const t = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
    'Sixty', 'Seventy', 'Eighty', 'Ninety',
  ];
  if (n < 20)       return u[n];
  if (n < 100)      return '${t[n ~/ 10]}${n % 10 != 0 ? ' ${u[n % 10]}' : ''}';
  if (n < 1000)     return '${u[n ~/ 100]} Hundred${n % 100 != 0 ? ' ${_toWords(n % 100)}' : ''}';
  if (n < 1000000)  return '${_toWords(n ~/ 1000)} Thousand${n % 1000 != 0 ? ' ${_toWords(n % 1000)}' : ''}';
  if (n < 1000000000) return '${_toWords(n ~/ 1000000)} Million${n % 1000000 != 0 ? ' ${_toWords(n % 1000000)}' : ''}';
  return n.toString();
}

// ─── Exam leaderboard / merit list PDF ───────────────────────────────────────

/// Builds a minimalist, monochrome A5 merit-list PDF matching the voucher style.
/// Used by the admin exam detail screen. Latin-only — no Bangla glyphs.
Future<Uint8List> buildExamMeritPdf({
  required String examTitle,
  required List<Map<String, dynamic>> rows,
  DateTime? generatedAt,
}) async {
  final fonts = await _loadFonts();
  final when  = generatedAt ?? DateTime.now();

  final doc = pw.Document(theme: fonts.buildTheme());

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 14),
              child: _buildHeader(
                fonts,
                address: kInstitutionAddress,
                phone: kInstitutionContact,
              ),
            )
          : pw.SizedBox.shrink(),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated ${_fmtDate(when)}',
              style: pw.TextStyle(font: fonts.sans, fontSize: 7, color: _muted),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(font: fonts.sans, fontSize: 7, color: _muted),
            ),
          ],
        ),
      ),
      build: (_) => [
        _buildMeritTitle(fonts, examTitle, when),
        pw.SizedBox(height: 12),
        _meritTable(fonts, rows),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _buildMeritTitle(_PdfFonts f, String examTitle, DateTime when) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'MERIT LIST',
              style: pw.TextStyle(
                font: f.sansBold,
                fontSize: 14,
                letterSpacing: 4,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              examTitle,
              style: pw.TextStyle(
                font: f.sansMedium,
                fontSize: 10,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
      _metaLine(f, 'Date', _fmtDate(when)),
    ],
  );
}

pw.Widget _meritTable(_PdfFonts f, List<Map<String, dynamic>> rows) {
  final headerStyle = pw.TextStyle(
    font: f.sansBold,
    fontSize: 7.5,
    letterSpacing: 2,
    color: _ink,
  );
  final cellStyle = pw.TextStyle(
    font: f.sans,
    fontSize: 9,
    color: _ink,
  );

  pw.Widget cell(
    String text, {
    pw.TextStyle? style,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      alignment: align,
      child: pw.Text(text, style: style ?? cellStyle),
    );
  }

  final headerRow = pw.TableRow(
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.8)),
    ),
    children: [
      cell('RANK', style: headerStyle, align: pw.Alignment.center),
      cell('STUDENT', style: headerStyle),
      cell('ID', style: headerStyle, align: pw.Alignment.center),
      cell('SCORE', style: headerStyle, align: pw.Alignment.centerRight),
      cell('GRADE', style: headerStyle, align: pw.Alignment.center),
    ],
  );

  final bodyRows = rows.map((row) {
    final user = Map<String, dynamic>.from(row['users'] as Map? ?? const {});
    final isAbsent = row['is_absent'] == true;
    final nameEn = (user['full_name_en'] as String?)?.trim();
    final sid = (user['student_id'] as String?)?.trim();
    final phone = (user['phone'] as String?)?.trim();
    final name = (nameEn != null && nameEn.isNotEmpty)
        ? nameEn
        : (sid != null && sid.isNotEmpty
            ? 'Student $sid'
            : (phone != null && phone.isNotEmpty ? 'Student $phone' : 'Student'));
    final score = isAbsent
        ? 'Absent'
        : '${row['score'] ?? 0} / ${row['total_marks'] ?? '-'}';
    final grade = isAbsent ? '-' : '${row['grade'] ?? '-'}';
    final rank  = '${row['rank'] ?? '-'}';
    return pw.TableRow(
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _hair, width: 0.3)),
      ),
      children: [
        cell(rank, align: pw.Alignment.center),
        cell(name),
        cell(sid ?? '-', align: pw.Alignment.center),
        cell(score, align: pw.Alignment.centerRight),
        cell(grade, align: pw.Alignment.center),
      ],
    );
  });

  return pw.Table(
    border: pw.TableBorder.all(color: _ink, width: 0.6),
    columnWidths: const {
      0: pw.FixedColumnWidth(34),
      1: pw.FlexColumnWidth(3),
      2: pw.FixedColumnWidth(56),
      3: pw.FixedColumnWidth(60),
      4: pw.FixedColumnWidth(40),
    },
    children: [headerRow, ...bodyRows],
  );
}
