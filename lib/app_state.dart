import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';
import 'repo.dart';

enum AuthStatus { loading, signedOut, denied, ready }

class AppState extends ChangeNotifier {
  AppState(this._repo) {
    _sub = FirebaseAuth.instance.authStateChanges().listen(_onUser);
  }

  final Repo _repo;
  late final StreamSubscription<User?> _sub;

  AuthStatus status = AuthStatus.loading;
  User? user;
  bool isAdmin = false;

  /// Administrador fijo (adminEmail): el único que puede nombrar o revertir admins.
  bool isOwner = false;
  String? error;

  String get uid => user!.uid;
  String get email => (user?.email ?? '').toLowerCase();

  Future<void> _onUser(User? u) async {
    user = u;
    isAdmin = false;
    isOwner = false;
    if (u == null) {
      _set(AuthStatus.signedOut);
      return;
    }
    _set(AuthStatus.loading);
    try {
      isOwner = email == adminEmail && u.emailVerified;
      isAdmin = isOwner;
      if (!isOwner) {
        final entry = await _repo.whitelistEntry(email);
        if (entry == null || !entry.approved) {
          _set(AuthStatus.denied);
          return;
        }
        isAdmin = await _repo.hasAdminFlag(email);
      }
      await _repo.registerUser(u, isAdmin: isAdmin, isOwner: isOwner);
      _set(AuthStatus.ready);
    } catch (e) {
      _set(AuthStatus.denied, e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    error = null;
    try {
      final provider = GoogleAuthProvider();
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(provider);
      }
    } on FirebaseAuthException catch (e) {
      const ignored = {'popup-closed-by-user', 'cancelled-popup-request', 'canceled'};
      if (!ignored.contains(e.code)) {
        error = e.message ?? e.code;
        notifyListeners();
      }
    }
  }

  Future<void> signOut() => FirebaseAuth.instance.signOut();

  void _set(AuthStatus s, [String? err]) {
    status = s;
    error = err;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
