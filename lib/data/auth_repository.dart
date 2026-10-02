/// The signed-in user as the app sees it.
final class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    this.email,
    this.photoUrl,
  });

  final String uid;
  final String displayName;
  final String? email;
  final String? photoUrl;
}

/// Sign-in with Google through Firebase Auth. Implemented in #14.
abstract interface class AuthRepository {
  /// Emits `null` when signed out.
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  /// Throws [AuthException] when the user cancels or sign-in fails.
  Future<AppUser> signInWithGoogle();

  Future<void> signOut();
}

final class AuthException implements Exception {
  const AuthException(this.message, {this.cancelled = false});

  /// Thai message that can be shown to the user as-is.
  final String message;

  /// The user closed the account picker; usually not worth an error.
  final bool cancelled;

  @override
  String toString() => 'AuthException: $message';
}
