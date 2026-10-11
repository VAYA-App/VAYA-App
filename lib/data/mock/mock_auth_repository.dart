import 'dart:async';

import '../auth_repository.dart';

/// Stand-in for Firebase Auth until Firebase is set up (deferred, see #14).
/// "Signing in with Google" succeeds immediately as a demo user.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({
    this.signInDelay = const Duration(milliseconds: 600),
    AppUser? initialUser,
  }) : _user = initialUser;

  static const demoUser = AppUser(
    uid: 'demo-user',
    displayName: 'ผู้ใช้ทดลอง',
    email: 'demo@vaya.app',
  );

  final Duration signInDelay;
  final _changes = StreamController<AppUser?>.broadcast();
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    await Future<void>.delayed(signInDelay);
    _set(demoUser);
    return demoUser;
  }

  @override
  Future<void> signOut() async => _set(null);

  void _set(AppUser? user) {
    _user = user;
    _changes.add(user);
  }

  void dispose() => _changes.close();
}
