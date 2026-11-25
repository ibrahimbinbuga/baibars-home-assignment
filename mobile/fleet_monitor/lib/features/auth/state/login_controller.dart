import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_notifier.dart';

enum LoginError { invalidCredentials, rateLimited, other }

class LoginFormState {
  const LoginFormState({
    this.busy = false,
    this.emailMissing = false,
    this.passwordMissing = false,
    this.error,
    this.errorText,
    this.cooldownSeconds = 0,
  });

  final bool busy;

  /// Client-side validation: an empty field is never sent to the server.
  final bool emailMissing;
  final bool passwordMissing;

  final LoginError? error;

  /// Message for [LoginError.other] (from the ApiException).
  final String? errorText;

  /// > 0 while rate limited: the button shows "Try again in 0:48" and stays disabled.
  final int cooldownSeconds;

  bool get coolingDown => cooldownSeconds > 0;
}

/// Login form logic: validation, the request, error mapping and the rate-limit countdown.
class LoginController extends Notifier<LoginFormState> {
  static const _fallbackCooldown = Duration(seconds: 60);
  Timer? _countdown;

  @override
  LoginFormState build() {
    ref.onDispose(() => _countdown?.cancel());
    return const LoginFormState();
  }

  /// Returns normally on success (the auth state change shows the app) and on handled failures (shown in state).
  Future<void> submit(String email, String password) async {
    if (state.busy || state.coolingDown) return;
    final emailMissing = email.trim().isEmpty;
    final passwordMissing = password.isEmpty;
    if (emailMissing || passwordMissing) {
      state = LoginFormState(
        emailMissing: emailMissing,
        passwordMissing: passwordMissing,
      );
      return;
    }

    state = const LoginFormState(busy: true);
    try {
      await ref.read(authProvider.notifier).login(email, password);
      if (ref.mounted) state = const LoginFormState();
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      if (e.isUnauthorized) {
        state = const LoginFormState(error: LoginError.invalidCredentials);
      } else if (e.isRateLimited) {
        _startCooldown(e.retryAfter ?? _fallbackCooldown);
      } else {
        state = LoginFormState(error: LoginError.other, errorText: e.title);
      }
    }
  }

  /// Typing again clears "required" markers and the invalid-credentials state (but not a running cooldown).
  void edited() {
    if (state.emailMissing ||
        state.passwordMissing ||
        state.error == LoginError.invalidCredentials ||
        state.error == LoginError.other) {
      state = LoginFormState(
        cooldownSeconds: state.cooldownSeconds,
        error: state.coolingDown ? LoginError.rateLimited : null,
      );
    }
  }

  void _startCooldown(Duration wait) {
    _countdown?.cancel();
    state = LoginFormState(
      error: LoginError.rateLimited,
      cooldownSeconds: wait.inSeconds,
    );
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = state.cooldownSeconds - 1;
      if (left <= 0) {
        timer.cancel();
        state = const LoginFormState();
      } else {
        state = LoginFormState(
          error: LoginError.rateLimited,
          cooldownSeconds: left,
        );
      }
    });
  }
}

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginFormState>(
      LoginController.new,
    );
