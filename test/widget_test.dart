import 'package:crops_recommendation/core/constants.dart';
import 'package:crops_recommendation/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin email is blocked from farmer registration check', () {
    expect(AuthService.isAdminEmail(kAdminEmail), isTrue);
    expect(AuthService.isAdminEmail('farmer@example.com'), isFalse);
    expect(AuthService.isAdminEmail('IT.ELIAS38@GMAIL.COM'), isTrue);
  });
}
