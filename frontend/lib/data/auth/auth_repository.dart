import 'package:shared_preferences/shared_preferences.dart';
import 'package:arka_payroll/core/network/api_client.dart';
import 'package:arka_payroll/domain/models/user_model.dart';

const _kTokenKey = 'arka_jwt';
const _kUserKey = 'arka_user_json';

class AuthRepository {
  late final ApiClient api;
  String? _token;
  UserModel? _user;

  AuthRepository() {
    api = ApiClient(getToken: () async => _token);
  }

  String? get token => _token;
  UserModel? get currentUser => _user;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kTokenKey);
  }

  Future<UserModel> login(String email, String password) async {
    final data = await api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    ) as Map<String, dynamic>;

    _token = data['accessToken'] as String;
    _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, _token!);

    return _user!;
  }

  Future<UserModel?> refreshMe() async {
    if (!isAuthenticated) return null;
    final data = await api.get('/auth/me') as Map<String, dynamic>;
    _user = UserModel.fromJson(data);
    return _user;
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserKey);
  }
}
