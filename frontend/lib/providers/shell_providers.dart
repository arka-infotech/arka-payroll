import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Bottom-tab index for the role shell (swipe + tap stay in sync).
class ShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (index < 0) return;
    state = index;
  }
}

final shellTabProvider =
    NotifierProvider<ShellTabNotifier, int>(ShellTabNotifier.new);

/// HR tab indices inside [MainTabShell] (employee shell uses different order).
abstract final class HrShellTabs {
  static const home = 0;
  static const people = 1;
  static const punch = 2;
  static const payslips = 3;
  static const leave = 4;
  static const calendar = 5;
  static const root = 6;
}

/// Whether the current route is a pushed detail screen (hide shell chrome).
final shellHideChromeProvider = StateProvider<bool>((ref) => false);
