/// Thrown when a phone number completes OTP but has no row in `public.users`.
class UnauthorizedUserException implements Exception {
  const UnauthorizedUserException([
    this.message = 'This phone is not registered. Contact the coaching center.',
  ]);

  final String message;

  @override
  String toString() => 'UnauthorizedUserException: $message';
}
