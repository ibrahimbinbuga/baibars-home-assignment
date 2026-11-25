import 'package:fleet_monitor/core/api/api_exception.dart';
import 'package:fleet_monitor/core/auth/token_storage.dart';
import 'package:fleet_monitor/core/theme/app_theme.dart';
import 'package:fleet_monitor/features/auth/data/auth_repository.dart';
import 'package:fleet_monitor/features/auth/ui/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  Future<void> pumpLogin(WidgetTester tester, {bool sessionEnded = false, String? email}) async {
    final storage = MockTokenStorage();
    when(storage.read).thenAnswer((_) async => null);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        tokenStorageProvider.overrideWithValue(storage),
      ],
      retry: (_, _) => null,
      child: MaterialApp(theme: AppTheme.light(), home: LoginScreen(sessionEnded: sessionEnded, initialEmail: email)),
    ));
    await tester.pump();
  }

  FilledButton signIn(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('signInButton')));

  testWidgets('Sign in stays disabled until both fields have text', (tester) async {
    await pumpLogin(tester);
    expect(signIn(tester).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('emailField')), 'admin@demo.local');
    await tester.pump();
    expect(signIn(tester).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('passwordField')), 'secret');
    await tester.pump();
    expect(signIn(tester).onPressed, isNotNull);
  });

  testWidgets('submitting with an empty field (keyboard "done") shows a field error and sends nothing', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.byKey(const Key('emailField')), 'admin@demo.local');
    await tester.showKeyboard(find.byKey(const Key('passwordField')));

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Enter your password.'), findsOneWidget);
    expect(find.text('One or more validation errors occurred.'), findsNothing);
    verifyNever(() => repository.login(any(), any()));
  });

  testWidgets('whitespace-only email counts as empty', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.byKey(const Key('emailField')), '   ');
    await tester.enterText(find.byKey(const Key('passwordField')), 'secret');
    await tester.pump();

    expect(signIn(tester).onPressed, isNull);
    await tester.showKeyboard(find.byKey(const Key('passwordField')));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Enter your email.'), findsOneWidget);
    verifyNever(() => repository.login(any(), any()));
  });

  testWidgets('wrong credentials show the generic message', (tester) async {
    when(() => repository.login(any(), any())).thenThrow(
        const ApiException(kind: ApiErrorKind.http, statusCode: 401, title: 'Invalid email or password.'));
    await pumpLogin(tester);
    await tester.enterText(find.byKey(const Key('emailField')), 'admin@demo.local');
    await tester.enterText(find.byKey(const Key('passwordField')), 'wrong');
    await tester.pump();

    await tester.tap(find.byKey(const Key('signInButton')));
    await tester.pump();

    expect(find.text('Invalid email or password.'), findsOneWidget);
  });

  testWidgets('rate limited: countdown from Retry-After, button disabled', (tester) async {
    when(() => repository.login(any(), any())).thenThrow(const ApiException(
        kind: ApiErrorKind.http, statusCode: 429, title: 'Too Many Requests', retryAfter: Duration(seconds: 48)));
    await pumpLogin(tester);
    await tester.enterText(find.byKey(const Key('emailField')), 'admin@demo.local');
    await tester.enterText(find.byKey(const Key('passwordField')), 'x');
    await tester.pump();

    await tester.tap(find.byKey(const Key('signInButton')));
    await tester.pump();

    expect(find.text('Too many attempts, try again in a minute.'), findsOneWidget);
    expect(find.text('Try again in 0:48'), findsOneWidget);
    expect(signIn(tester).onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Try again in 0:47'), findsOneWidget);

    await tester.pump(const Duration(seconds: 47));
    expect(find.text('Sign in'), findsOneWidget);
    expect(signIn(tester).onPressed, isNotNull);
  });

  testWidgets('after a session ends: banner shown and email prefilled', (tester) async {
    await pumpLogin(tester, sessionEnded: true, email: 'tarsus.operator@demo.local');

    expect(find.text('Session expired, please sign in again.'), findsOneWidget);
    expect(find.text('tarsus.operator@demo.local'), findsOneWidget);
  });
}
