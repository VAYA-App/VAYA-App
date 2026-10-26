import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_repository.dart';

/// การเข้าสู่ระบบจริงด้วย Firebase Authentication ร่วมกับ Google Sign-In (#14)
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    fb.FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _mapUser(user);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth
        .authStateChanges()
        .map((user) => user == null ? null : _mapUser(user));
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // ผู้ใช้ปิดกล่องเลือกบัญชีหรือไม่เลือกบัญชี
        throw const AuthException(
          'ผู้ใช้ยกเลิกการเลือกบัญชี',
          cancelled: true,
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw const AuthException('เข้าสู่ระบบไม่สำเร็จ ข้อมูลผู้ใช้ไม่ถูกต้อง');
      }

      return _mapUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(
        switch (e.code) {
          'account-exists-with-different-credential' =>
            'อีเมลนี้ผูกกับช่องทางการเข้าสู่ระบบอื่นแล้ว',
          'network-request-failed' =>
            'เครือข่ายขัดข้อง กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต',
          'user-disabled' => 'บัญชีนี้ถูกระงับการใช้งาน',
          _ => 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ (${e.message ?? e.code})',
        },
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('เกิดข้อผิดพลาดในการเข้าสู่ระบบ: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await Future.wait([
        _googleSignIn.signOut(),
        _auth.signOut(),
      ]);
    } catch (_) {
      // พยายาม sign out ทั้งสองส่วน แม้ service ใดตัวหนึ่ง error
      await _auth.signOut();
    }
  }

  static AppUser _mapUser(fb.User user) {
    final name = user.displayName?.trim();
    return AppUser(
      uid: user.uid,
      displayName: (name != null && name.isNotEmpty)
          ? name
          : (user.email ?? 'ผู้ใช้ VAYA'),
      email: user.email,
      photoUrl: user.photoURL,
    );
  }
}
