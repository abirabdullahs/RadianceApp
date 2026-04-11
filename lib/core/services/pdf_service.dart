import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../student_id_display.dart';
import '../../shared/models/course_model.dart';
import '../../shared/models/payment_model.dart';
import '../../shared/models/user_model.dart';

// ─── Color Palette ────────────────────────────────────────────────────────────
// Deep Indigo (#1A237E) + Amber (#FFC107) modern scheme
const _primary = PdfColor(0.102, 0.137, 0.494); // #1A237E
const _accent  = PdfColor(1.000, 0.757, 0.027); // #FFC107
const _surface = PdfColor(0.961, 0.961, 0.961); // #F5F5F5
const _dark    = PdfColor(0.129, 0.129, 0.129); // #212121
const _green   = PdfColor(0.161, 0.502, 0.275); // discount green
const _yellow  = PdfColor(1.000, 1.000, 0.878); // note bg

/// Generates printable PDF documents (payment vouchers).
/// Supports Bengali text via HindSiliguri TTF, logo image, and modern layout.
///
/// ── Asset requirements (add to pubspec.yaml) ─────────────────────────────────
///   flutter:
///     assets:
///       - assets/fonts/HindSiliguri-Regular.ttf
///       - assets/fonts/HindSiliguri-Bold.ttf
///       - assets/images/logo.png            # optional
/// ─────────────────────────────────────────────────────────────────────────────
class PdfService {
  PdfService();

  /// Generates a modern A5 payment voucher as PDF bytes.
  ///
  /// Parameters:
  ///   [payment]            — core payment data
  ///   [student]            — student model (supports both EN and BN name)
  ///   [course]             — course model
  ///   [serviceName]        — optional service label (e.g. "Monthly Tuition")
  ///   [logoBytes]          — optional PNG/JPEG logo bytes from assets or network
  ///   [institutionAddress] — optional address line shown in header
  ///   [institutionPhone]   — optional contact shown in header
  ///   [footerNote]         — custom footer text (overrides default)
  ///   [batchName]          — NEW: student's batch / academic session
  ///   [guardianName]       — NEW: parent / guardian name
  Future<Uint8List> generateVoucherPdf(
    PaymentModel payment,
    UserModel student,
    CourseModel course, {
    String? serviceName,
    Uint8List? logoBytes,
    String? institutionAddress,
    String? institutionPhone,
    String? footerNote,
    String? batchName,       // NEW field
    String? guardianName,    // NEW field
  }) async {
    // ── Bengali font (Hind Siliguri) ─────────────────────────────────────────
    final bnRegData  = await rootBundle.load('assets/fonts/HindSiliguri-Regular.ttf');
    final bnBoldData = await rootBundle.load('assets/fonts/HindSiliguri-Bold.ttf');
    final bnFont     = pw.Font.ttf(bnRegData);
    final bnBold     = pw.Font.ttf(bnBoldData);

    // ── Data prep ────────────────────────────────────────────────────────────
    final paidDate   = payment.paidAt ?? DateTime.now();
    final monthLabel = _fmtMonth(payment.forMonth);
    final method     = payment.paymentMethod?.name ?? '—';
    final total      = payment.amount;
    final inWords    = _amountInWordsTaka(total);
    final svc        = serviceName?.trim().isNotEmpty == true ? serviceName!.trim() : '—';

    final nameEn = student.fullNameEn?.trim().isNotEmpty == true
        ? student.fullNameEn!.trim()
        : null;
    final nameBn = student.fullNameBn;

    pw.ImageProvider? logo;
    if (logoBytes != null) logo = pw.MemoryImage(logoBytes);

    // ── Build document ───────────────────────────────────────────────────────
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── 1. Header ──────────────────────────────────────────────────
            _buildHeader(
              logo: logo,
              bnFont: bnFont,
              bnBold: bnBold,
              address: institutionAddress,
              phone: institutionPhone,
            ),

            // ── 2. Title / meta strip ──────────────────────────────────────
            _buildTitleStrip(payment.voucherNo, paidDate),

            // ── 3. Body ────────────────────────────────────────────────────
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // Two-column info cards
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: _buildCard('STUDENT INFO', [
                            _field('Name (EN)', nameEn ?? '—'),
                            _fieldBn('Name (BN)', nameBn, bnFont),
                            _field('Student ID', displayStudentIdForUser(student)),
                            _field('Phone', student.phone),
                            if (guardianName?.trim().isNotEmpty == true)
                              _field('Guardian', guardianName!.trim()),
                            if (batchName?.trim().isNotEmpty == true)
                              _field('Batch / Session', batchName!.trim()),
                          ]),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: _buildCard('PAYMENT INFO', [
                            _field('Course', course.name),
                            _field('Service', svc),
                            _field('Billing Month', monthLabel),
                            _field('Payment Method', method),
                            _field('Payment Status', 'PAID'),
                          ]),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 12),

                    // Amount table
                    _buildAmountTable(payment, total, inWords),

                    // Note box (if any)
                    if (payment.note?.trim().isNotEmpty == true) ...[
                      pw.SizedBox(height: 10),
                      _buildNoteBox(payment.note!.trim()),
                    ],

                    pw.Spacer(),

                    // Signature row
                    _buildSignatures(),
                  ],
                ),
              ),
            ),

            // ── 4. Footer ──────────────────────────────────────────────────
            _buildFooter(footerNote),
          ],
        ),
      ),
    );

    return doc.save();
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

pw.Widget _buildHeader({
  required pw.ImageProvider? logo,
  required pw.Font bnFont,
  required pw.Font bnBold,
  String? address,
  String? phone,
}) {
  return pw.Container(
    color: _primary,
    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Logo / monogram box
        pw.Container(
          width: 52,
          height: 52,
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          alignment: pw.Alignment.center,
          child: logo != null
              ? pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                )
              : pw.Text(
                  'R',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                  ),
                ),
        ),
        pw.SizedBox(width: 14),

        // Institute name block
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'RADIANCE COACHING CENTER',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'রেডিয়েন্স কোচিং সেন্টার',
              style: pw.TextStyle(
                fontSize: 9,
                color: _accent,
                font: bnFont,
              ),
            ),
            pw.SizedBox(height: 3),
            if (address != null && address.isNotEmpty)
              pw.Text(
                address,
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
              ),
            if (phone != null && phone.isNotEmpty)
              pw.Text(
                'Phone: $phone',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
              ),
          ],
        ),
      ],
    ),
  );
}

// ─── Title strip ──────────────────────────────────────────────────────────────

pw.Widget _buildTitleStrip(String voucherNo, DateTime date) {
  return pw.Container(
    color: _accent,
    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 7),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'PAYMENT RECEIPT',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _dark,
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Voucher #$voucherNo',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _dark,
              ),
            ),
            pw.Text(
              'Date: ${_fmtDate(date)}',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.black),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─── Info card ────────────────────────────────────────────────────────────────

pw.Widget _buildCard(String title, List<pw.Widget> fields) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Card header
        pw.Container(
          decoration: pw.BoxDecoration(
            color: _primary,
            borderRadius: pw.BorderRadius.only(
              topLeft: const pw.Radius.circular(5),
              topRight: const pw.Radius.circular(5),
            ),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 6.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        // Card body
        pw.Padding(
          padding: const pw.EdgeInsets.all(9),
          child: pw.Column(children: fields),
        ),
      ],
    ),
  );
}

// ─── Field widgets ────────────────────────────────────────────────────────────

/// Latin/English field
pw.Widget _field(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 1),
        pw.Text(value, style: const pw.TextStyle(fontSize: 8.5)),
      ],
    ),
  );
}

/// Bengali field — uses TTF font
pw.Widget _fieldBn(String label, String value, pw.Font font) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 1),
        pw.Text(value, style: pw.TextStyle(fontSize: 8.5, font: font)),
      ],
    ),
  );
}

// ─── Amount table ─────────────────────────────────────────────────────────────

pw.Widget _buildAmountTable(PaymentModel payment, double total, String words) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
      children: [
        // Table header
        pw.Container(
          decoration: pw.BoxDecoration(
            color: _primary,
            borderRadius: pw.BorderRadius.only(
              topLeft: const pw.Radius.circular(5),
              topRight: const pw.Radius.circular(5),
            ),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'DESCRIPTION',
                style: pw.TextStyle(
                  fontSize: 6.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                'AMOUNT',
                style: pw.TextStyle(
                  fontSize: 6.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ],
          ),
        ),

        // Subtotal row
        _tableRow(
          'Course Fee (Subtotal)',
          '৳ ${payment.subtotal.toStringAsFixed(2)}',
          shade: false,
        ),

        // Discount row (conditional)
        if (payment.discount > 0)
          _tableRow(
            'Discount Applied',
            '− ৳ ${payment.discount.toStringAsFixed(2)}',
            shade: true,
            isDiscount: true,
          ),

        // Grand total (accent highlight)
        pw.Container(
          color: _accent,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'GRAND TOTAL',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _dark,
                ),
              ),
              pw.Text(
                '৳ ${total.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _dark,
                ),
              ),
            ],
          ),
        ),

        // Amount in words
        pw.Container(
          color: _surface,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: 'In Words: ',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.TextSpan(
                  text: words,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontStyle: pw.FontStyle.italic,
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

pw.Widget _tableRow(
  String label,
  String value, {
  bool shade = false,
  bool isDiscount = false,
}) {
  return pw.Container(
    color: shade ? _surface : PdfColors.white,
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 8.5,
            color: isDiscount ? _green : _dark,
          ),
        ),
      ],
    ),
  );
}

// ─── Note box ─────────────────────────────────────────────────────────────────

pw.Widget _buildNoteBox(String note) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      color: _yellow,
      border: pw.Border(
        left: pw.BorderSide(color: _accent, width: 3),
      ),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: 'Note: ',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.TextSpan(
            text: note,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    ),
  );
}

// ─── Signatures ───────────────────────────────────────────────────────────────

pw.Widget _buildSignatures() {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 4),
    child: pw.Row(
      children: [
        _sigBlock("Student's Signature"),
        pw.SizedBox(width: 30),
        _sigBlock('Authorized Signature & Stamp'),
      ],
    ),
  );
}

pw.Widget _sigBlock(String label) {
  return pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 22),
        pw.Container(height: 0.5, color: PdfColors.grey500),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
      ],
    ),
  );
}

// ─── Footer ───────────────────────────────────────────────────────────────────

pw.Widget _buildFooter(String? note) {
  return pw.Container(
    color: _primary,
    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: pw.Text(
      note ??
          'Thank you for choosing Radiance Coaching Center. '
              'This is a computer-generated receipt.',
      textAlign: pw.TextAlign.center,
      style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
    ),
  );
}

// ─── Pure helpers ─────────────────────────────────────────────────────────────

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
