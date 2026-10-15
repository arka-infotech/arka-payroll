import 'package:flutter/foundation.dart';
import 'package:arka_payroll/data/auth/auth_repository.dart';
import 'package:arka_payroll/domain/models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends ChangeNotifier {
  AuthState(this._repo);

  final AuthRepository _repo;
  AuthStatus status = AuthStatus.unknown;
  UserModel? user;
  String? error;
  bool busy = false;

  Future<void> bootstrap() async {
    if (!_repo.isAuthenticated) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      user = await _repo.refreshMe();
      status = user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
    } catch (_) {
      await _repo.logout();
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      user = await _repo.login(email, password);
      status = AuthStatus.authenticated;
      busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      status = AuthStatus.unauthenticated;
      busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
