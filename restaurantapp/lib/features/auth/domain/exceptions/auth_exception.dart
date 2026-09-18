enum AuthRegistrationFailure {
  duplicateEmail,
  emailConfirmationRequired,
  emailRateLimit,
  unknown,
}

class AuthRegistrationException implements Exception {
  const AuthRegistrationException(this.failure, this.message);

  final AuthRegistrationFailure failure;
  final String message;
}
