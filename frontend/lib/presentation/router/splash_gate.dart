import 'package:flutter/foundation.dart';

/// Coordinates one-time cold-start splash with GoRouter redirects.
class SplashGate extends ChangeNotifier {
  bool _done = false;

  bool get done => _done;

  void complete() {
    if (_done) return;
    _done = true;
    notifyListeners();
  }
}
