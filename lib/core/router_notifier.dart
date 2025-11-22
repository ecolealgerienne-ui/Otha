import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_controller.dart';

/// Notifier qui permet à GoRouter de réagir aux changements de session
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<SessionState>(
      sessionProvider,
      (_, __) => notifyListeners(),
    );
  }

  bool get isLoggedIn => _ref.read(sessionProvider).user != null;

  String? get userRole => _ref.read(sessionProvider).user?['role']?.toString();
}
