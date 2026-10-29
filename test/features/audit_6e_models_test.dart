import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/account/account_repository.dart';
import 'package:frontend/features/account/email_verification_dialog.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/features/commerce/commerce_models.dart';

void main() {
  test('a report shows the unit symbol and its photo address', () {
    final report = Contribution.fromJson({
      'id': 1,
      'unit_code': 'pp-kg',
      'unit_symbol': 'kg',
      'has_photo': true,
      'photo': 'http://api/api/contributions/1/photo/',
    });
    expect(report.unit, 'kg');
    expect(report.photoPath, endsWith('/photo/'));
  });

  test('without a symbol the unit code is kept', () {
    final report = Contribution.fromJson({'id': 2, 'unit_code': 'kg'});
    expect(report.unit, 'kg');
  });

  test('a payment carries what is left to refund and when to retry', () {
    final payment = Payment.fromJson({
      'payment_number': 'PAY-1',
      'order': 3,
      'status': 'timeout',
      'amount': '1000.00',
      'amount_refunded': '400.00',
      'amount_remaining': '600.00',
      'retry_available_at': '2026-10-29T12:00:00Z',
    });
    expect(payment.amountRemaining, '600.00');
    expect(
      payment.retryAvailableAt?.isAtSameMomentAs(
        DateTime.utc(2026, 10, 29, 12),
      ),
      isTrue,
    );
  });

  test('an unverified address is recognised from its error code', () {
    const error = ApiException(
      kind: ApiErrorKind.http,
      statusCode: 403,
      code: 'email_not_verified',
    );
    expect(isEmailNotVerified(error), isTrue);
    expect(isEmailNotVerified(Exception('x')), isFalse);
  });
}
