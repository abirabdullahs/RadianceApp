import 'package:flutter_test/flutter_test.dart';
import 'package:radiance/shared/models/payment_due_model.dart';

void main() {
  test('dateToSqlDate normalizes to YYYY-MM-DD', () {
    expect(dateToSqlDate(DateTime.utc(2025, 4, 9)), '2025-04-09');
  });
}
