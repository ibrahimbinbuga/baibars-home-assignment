// ⚠ TEMPORARY DEBUG UI (Phase 5a). Only for checking the login flow against the backend.
// Replaced by the designed login screen in Phase 5b.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';

class DebugLoginScreen extends ConsumerStatefulWidget {
  const DebugLoginScreen({super.key, this.reason});

  final LogoutReason? reason;

  @override
  ConsumerState<DebugLoginScreen> createState() => _DebugLoginScreenState();
}

class _DebugLoginScreenState extends ConsumerState<DebugLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(_email.text, _password.text);
    } on ApiException catch (e) {
      setState(() => _error = switch (e) {
            ApiException(isUnauthorized: true) => 'Invalid email or password.',
            ApiException(isRateLimited: true) => 'Too many attempts. Try again in a minute.',
            _ => e.title,
          });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasonText = switch (widget.reason) {
      LogoutReason.sessionExpired => 'Your session expired. Please log in again.',
      LogoutReason.unauthorized => 'You were signed out. Please log in again.',
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('DEBUG login (temporary)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (reasonText != null) Text(reasonText, key: const Key('logoutReason')),
          TextField(
            key: const Key('email'),
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
          ),
          TextField(
            key: const Key('password'),
            controller: _password,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('loginButton'),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Logging in…' : 'Log in'),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!)),
        ],
      ),
    );
  }
}
