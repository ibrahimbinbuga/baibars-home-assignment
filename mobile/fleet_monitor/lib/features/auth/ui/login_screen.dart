import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/spacing.dart';
import '../state/login_controller.dart';

/// Sign in (Login.dc.html 1.1–1.5). [sessionEnded] shows the "Session expired" banner; [initialEmail] prefills.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.sessionEnded = false, this.initialEmail});

  final bool sessionEnded;
  final String? initialEmail;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Rebuild so the button enables/disables as the user types.
    _email.addListener(_onEdited);
    _password.addListener(_onEdited);
  }

  void _onEdited() {
    setState(() {});
    ref.read(loginControllerProvider.notifier).edited();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => ref
      .read(loginControllerProvider.notifier)
      .submit(_email.text, _password.text);

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(loginControllerProvider);
    final bothFilled =
        _email.text.trim().isNotEmpty && _password.text.isNotEmpty;
    final invalid = form.error == LoginError.invalidCredentials;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.sessionEnded) const _SessionExpiredBanner(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        72,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Brand(),
                          const SizedBox(height: AppSpacing.xl),
                          AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Label('Email'),
                                TextField(
                                  key: const Key('emailField'),
                                  controller: _email,
                                  enabled: !form.busy,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  textInputAction: TextInputAction.next,
                                  style: AppText.bodyLarge,
                                  decoration: _decoration(
                                    hint: 'name@company.com',
                                    error: invalid || form.emailMissing,
                                    errorText: form.emailMissing
                                        ? 'Enter your email.'
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _Label('Password'),
                                TextField(
                                  key: const Key('passwordField'),
                                  controller: _password,
                                  enabled: !form.busy,
                                  obscureText: _obscure,
                                  autofillHints: const [AutofillHints.password],
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                  style: AppText.bodyLarge,
                                  decoration: _decoration(
                                    hint: 'Password',
                                    error: invalid || form.passwordMissing,
                                    errorText: form.passwordMissing
                                        ? 'Enter your password.'
                                        : null,
                                    suffix: IconButton(
                                      tooltip: _obscure
                                          ? 'Show password'
                                          : 'Hide password',
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 22,
                                      ),
                                      color: AppPalette.onSurfaceVariant,
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (form.error != null) ...[
                            const SizedBox(height: 20),
                            _ErrorBox(form),
                          ],
                          const SizedBox(height: 24),
                          _SubmitButton(
                            form: form,
                            enabled: bothFilled,
                            onPressed: _submit,
                          ),
                          const Spacer(),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Read-only monitoring. Accounts are managed by your administrator.',
                            textAlign: TextAlign.center,
                            style: AppText.labelMedium.copyWith(
                              fontWeight: FontWeight.w400,
                              height: 20 / 13,
                              color: AppPalette.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String hint,
    required bool error,
    String? errorText,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecoration(
      hintText: hint,
      errorText: errorText,
      suffixIcon: suffix,
      // Invalid credentials: both fields get a 2 px red outline, without saying which one is wrong.
      enabledBorder: error ? border(AppPalette.error, 2) : null,
      focusedBorder: error ? border(AppPalette.error, 2) : null,
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppPalette.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.location_on_outlined,
          size: 30,
          color: AppPalette.onPrimary,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Semantics(
        header: true,
        child: Text('Fleet Monitor', style: AppText.headlineMedium),
      ),
      const SizedBox(height: AppSpacing.xxs),
      Text(
        'Sign in with your operations account.',
        style: AppText.bodyLarge.copyWith(color: AppPalette.onSurfaceVariant),
      ),
    ],
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: AppText.bodyMedium.copyWith(
        fontWeight: FontWeight.w600,
        color: AppPalette.textStrong,
      ),
    ),
  );
}

class _SessionExpiredBanner extends StatelessWidget {
  const _SessionExpiredBanner();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: const Key('sessionExpiredBanner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        color: AppPalette.warningContainer,
        border: Border(bottom: BorderSide(color: AppPalette.warningBorder)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule,
            size: 18,
            color: AppPalette.onWarningContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Session expired, please sign in again.',
              style: AppText.labelLarge.copyWith(
                color: AppPalette.onWarningContainer,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.form);

  final LoginFormState form;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (form.error!) {
      LoginError.invalidCredentials => (
        Icons.error_outline,
        'Invalid email or password.',
      ),
      LoginError.rateLimited => (
        Icons.schedule,
        'Too many attempts, try again in a minute.',
      ),
      LoginError.other => (
        Icons.error_outline,
        form.errorText ?? 'Sign in failed. Try again.',
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppPalette.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: AppPalette.onErrorContainer),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppText.labelLarge.copyWith(
                  height: 22 / 15,
                  color: AppPalette.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.form,
    required this.enabled,
    required this.onPressed,
  });

  final LoginFormState form;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cooldown = form.cooldownSeconds;
    final label = form.busy
        ? 'Signing in…'
        : form.coolingDown
        ? 'Try again in ${cooldown ~/ 60}:${(cooldown % 60).toString().padLeft(2, '0')}'
        : 'Sign in';
    final active = enabled && !form.busy && !form.coolingDown;

    return SizedBox(
      height: 56,
      child: FilledButton(
        key: const Key('signInButton'),
        onPressed: active ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: AppPalette.onPrimary,
          // Loading keeps the ink colour (slightly lighter); rate limited / empty use the disabled grey.
          disabledBackgroundColor: form.busy
              ? AppPalette.primaryBusy
              : AppPalette.disabledButton,
          disabledForegroundColor: form.busy
              ? AppPalette.onPrimary
              : AppPalette.onDisabledButton,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          textStyle: AppText.titleSmall.copyWith(fontSize: 17),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (form.busy) ...[
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppPalette.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(label, style: AppText.tabular(const TextStyle())),
          ],
        ),
      ),
    );
  }
}
