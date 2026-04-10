import 'dart:convert';

class ImportErrorItem {
  const ImportErrorItem(this.index, this.message);
  final int index;
  final String message;
}

class QbankImportResult {
  const QbankImportResult({
    required this.type,
    required this.validRows,
    required this.errors,
    required this.totalCount,
  });

  final String type; // mcq | cq
  final List<Map<String, dynamic>> validRows;
  final List<ImportErrorItem> errors;
  final int totalCount;
}

class QBankJsonImporter {
  QbankImportResult parse(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('JSON must be an object');
    }

    final type = (decoded['type'] ?? '').toString().toLowerCase().trim();
    if (type != 'mcq' && type != 'cq') {
      throw FormatException('type must be mcq or cq');
    }

    final list = decoded['questions'];
    if (list is! List) {
      throw FormatException('questions must be an array');
    }

    final valid = <Map<String, dynamic>>[];
    final errors = <ImportErrorItem>[];

    for (var i = 0; i < list.length; i++) {
      final rowRaw = list[i];
      if (rowRaw is! Map) {
        errors.add(ImportErrorItem(i + 1, 'Invalid object'));
        continue;
      }
      final row = Map<String, dynamic>.from(rowRaw);
      final rowErrors = type == 'mcq' ? _validateMcq(row) : _validateCq(row);
      if (rowErrors.isEmpty) {
        valid.add(row);
      } else {
        for (final e in rowErrors) {
          errors.add(ImportErrorItem(i + 1, e));
        }
      }
    }

    return QbankImportResult(
      type: type,
      validRows: valid,
      errors: errors,
      totalCount: list.length,
    );
  }

  List<String> _validateMcq(Map<String, dynamic> q) {
    final errors = <String>[];
    if (_blank(q['question_text'])) errors.add('question_text missing');
    if (_blank(q['option_a'])) errors.add('option_a missing');
    if (_blank(q['option_b'])) errors.add('option_b missing');
    if (_blank(q['option_c'])) errors.add('option_c missing');
    if (_blank(q['option_d'])) errors.add('option_d missing');
    final correct = (q['correct_option'] ?? '').toString().toUpperCase().trim();
    if (!const ['A', 'B', 'C', 'D'].contains(correct)) {
      errors.add('correct_option must be A/B/C/D');
    }
    return errors;
  }

  List<String> _validateCq(Map<String, dynamic> q) {
    final errors = <String>[];
    if (_blank(q['stem_text'])) errors.add('stem_text missing');
    if (_blank(q['ga_text'])) errors.add('ga_text missing');
    if (_blank(q['gha_text'])) errors.add('gha_text missing');
    final gaMarks = _toInt(q['ga_marks']);
    final ghaMarks = _toInt(q['gha_marks']);
    if (gaMarks != null && gaMarks <= 0) errors.add('ga_marks must be > 0');
    if (ghaMarks != null && ghaMarks <= 0) errors.add('gha_marks must be > 0');
    return errors;
  }

  bool _blank(dynamic v) => v == null || v.toString().trim().isEmpty;
  int? _toInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse('${v ?? ''}');
}
