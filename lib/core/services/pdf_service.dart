import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/models/course_model.dart';
import '../../shared/models/payment_model.dart';
import '../../shared/models/user_model.dart';

/// Generates printable PDF documents (payment vouchers, etc.).
class PdfService {
  PdfService();

  /// Builds a payment voucher as PDF bytes (A5). Uses Helvetica (Latin); Bengali names may
  /// need a TTF font if glyphs do not render in all viewers.
  Future<Uint8List> generateVoucherPdf(
    PaymentModel payment,
    UserModel student,
    CourseModel course,
  ) async {
    final paidDate = payment.paidAt ?? DateTime.now();
    final monthLabel = _formatMonthEnglish(payment.forMonth);
    final methodLabel = payment.paymentMethod?.name ?? '—';
    final amountWords = _amountInWordsTaka(payment.amount);
    final displayName = (student.fullNameEn != null &&
            student.fullNameEn!.trim().isNotEmpty)
        ? student.fullNameEn!.trim()
        : student.fullNameBn;

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'RADIANCE COACHING CENTER',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Payment Receipt / Voucher',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Voucher No: ${payment.voucherNo}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.Text(
                    'Date: ${_formatDate(paidDate)}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 8),
              _row('Student', displayName),
              if (student.studentId != null && student.studentId!.isNotEmpty)
                _row('Student ID', student.studentId!),
              _row('Phone', student.phone),
              _row('Course', course.name),
              _row('Billing month', monthLabel),
              _row('Amount (figures)', '৳ ${payment.amount.toStringAsFixed(2)}'),
              _row('Amount (in words)', amountWords),
              _row('Payment method', methodLabel),
              if (payment.note != null && payment.note!.trim().isNotEmpty)
                _row('Note', payment.note!.trim()),
              pw.SizedBox(height: 28),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 140,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              top: pw.BorderSide(width: 0.5),
                            ),
                          ),
                          padding: const pw.EdgeInsets.only(top: 4),
                          child: pw.Text(
                            'Authorized signature',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Text(
                'Thank you for your payment.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}

pw.Widget _row(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    ),
  );
}

String _formatDate(DateTime d) {
  final local = d.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}

String _formatMonthEnglish(DateTime forMonth) {
  const names = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[forMonth.month - 1]} ${forMonth.year}';
}

/// Integer taka amount in English words, plus paisa if fractional.
String _amountInWordsTaka(double amount) {
  if (amount < 0) return 'Invalid amount';
  final whole = amount.floor();
  final frac = ((amount - whole) * 100).round() % 100;
  final w = _numberToWordsEn(whole);
  if (frac == 0) {
    return 'Taka $w Only';
  }
  final p = _numberToWordsEn(frac);
  return 'Taka $w and $p Paisa Only';
}

String _numberToWordsEn(int n) {
  if (n == 0) return 'Zero';
  if (n < 0) return 'Minus ${_numberToWordsEn(-n)}';

  const units = <String>[
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];
  const tens = <String>[
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];

  if (n < 20) return units[n];
  if (n < 100) {
    final t = n ~/ 10;
    final u = n % 10;
    return u == 0 ? tens[t] : '${tens[t]} ${units[u]}';
  }
  if (n < 1000) {
    final h = n ~/ 100;
    final r = n % 100;
    final head = '${units[h]} Hundred';
    return r == 0 ? head : '$head ${_numberToWordsEn(r)}';
  }
  if (n < 1000000) {
    final th = n ~/ 1000;
    final r = n % 1000;
    final head = '${_numberToWordsEn(th)} Thousand';
    return r == 0 ? head : '$head ${_numberToWordsEn(r)}';
  }
  if (n < 1000000000) {
    final m = n ~/ 1000000;
    final r = n % 1000000;
    final head = '${_numberToWordsEn(m)} Million';
    return r == 0 ? head : '$head ${_numberToWordsEn(r)}';
  }
  return n.toString();
}
