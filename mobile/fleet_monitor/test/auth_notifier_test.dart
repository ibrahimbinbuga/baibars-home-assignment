import 'package:fleet_monitor/core/api/api_exception.dart';
import 'package:fleet_monitor/core/auth/auth_notifier.dart';
import 'package:fleet_monitor/core/auth/auth_state.dart';
import 'package:fleet_monitor/core/auth/token_storage.dart';
import 'package:fleet_monitor/core/clock.dart';
import 'package:fleet_monitor/features/auth/data/auth_models.dart';
import 'package:fleet_monitor/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  final now = DateTime.utc(2026, 11, 26, 10);
  const user = UserInfo(
    id: 'u-1',
    email: 'admin@demo.local',
    displayName: 'Demo Admin',
    role: Role.admin,
  );

  late MockTokenStorage storage;
  late MockAuthRepository repository;

  setUpAll(() {
    registerFallbackValue(
      StoredSession(accessToken: '', expiresAt: now, user: user),
    );
  });

  setUp(() {
    storage = MockTokenStorage();
    repository = MockAuthRepository();
    when(() => storage.clear()).thenAnswer((_) async {});
    when(() => storage.write(any())).thenAnswer((_) async {});
  });

  ProviderContainer createContainer({DateTime? at}) => ProviderContainer.test(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repository),
      clockProvider.overrideWithValue(() => at ?? now),
    ],
  );

  test('no stored token → login screen, no reason', () async {
    when(() => storage.read()).thenAnswer((_) async => null);

    final state = await createContainer().read(authProvider.future);

    expect(
      state,
      isA<Unauthenticated>().having((s) => s.reason, 'reason', isNull),
    );
  });

  test(
    'expired stored token → login with "session expired", storage cleared',
    () async {
      when(() => storage.read()).thenAnswer(
        (_) async => StoredSession(
          accessToken: 'old',
          expiresAt: now.subtract(const Duration(minutes: 1)),
          user: user,
        ),
      );

      final state = await createContainer().read(authProvider.future);

      expect(
        state,
        isA<Unauthenticated>().having(
          (s) => s.reason,
          'reason',
          LogoutReason.sessionExpired,
        ),
      );
      verify(() => storage.clear()).called(1);
    },
  );

  test('token expiring exactly now counts as expired', () async {
    when(() => storage.read()).thenAnswer(
      (_) async =>
          StoredSession(accessToken: 'old', expiresAt: now, user: user),
    );

    final state = await createContainer().read(authProvider.future);

    expect(state, isA<Unauthenticated>());
  });

  test('valid stored token → authenticated without a network call', () async {
    when(() => storage.read()).thenAnswer(
      (_) async => StoredSession(
        accessToken: 'jwt',
        expiresAt: now.add(const Duration(minutes: 30)),
        user: user,
      ),
    );

    final state = await createContainer().read(authProvider.future);

    expect(
      state,
      isA<Authenticated>().having((s) => s.accessToken, 'token', 'jwt'),
    );
    verifyZeroInteractions(repository);
  });

  test('login stores the session and authenticates', () async {
    when(() => storage.read()).thenAnswer((_) async => null);
    when(() => repository.login('admin@demo.local', 'Admin123!')).thenAnswer(
      (_) async => LoginResponse(
        accessToken: 'jwt',
        expiresAt: now.add(const Duration(hours: 1)),
        user: user,
      ),
    );
    final container = createContainer();
    await container.read(authProvider.future);

    await container
        .read(authProvider.notifier)
        .login('  admin@demo.local ', 'Admin123!');

    expect(container.read(authProvider).value, isA<Authenticated>());
    verify(() => storage.write(any())).called(1);
  });

  test('failed login stays logged out and rethrows', () async {
    when(() => storage.read()).thenAnswer((_) async => null);
    when(() => repository.login(any(), any())).thenThrow(
      const ApiException(
        kind: ApiErrorKind.http,
        statusCode: 401,
        title: 'Invalid email or password.',
      ),
    );
    final container = createContainer();
    await container.read(authProvider.future);

    await expectLater(
      container.read(authProvider.notifier).login('a@b.c', 'x'),
      throwsA(isA<ApiException>()),
    );

    expect(container.read(authProvider).value, isA<Unauthenticated>());
    verifyNever(() => storage.write(any()));
  });

  test('logout keeps the first reason when several 401s arrive', () async {
    when(() => storage.read()).thenAnswer(
      (_) async => StoredSession(
        accessToken: 'jwt',
        expiresAt: now.add(const Duration(minutes: 30)),
        user: user,
      ),
    );
    final container = createContainer();
    await container.read(authProvider.future);
    final notifier = container.read(authProvider.notifier);

    await notifier.logout(LogoutReason.unauthorized);
    await notifier.logout(LogoutReason.userRequested);

    expect(
      container.read(authProvider).value,
      isA<Unauthenticated>().having(
        (s) => s.reason,
        'reason',
        LogoutReason.unauthorized,
      ),
    );
    verify(() => storage.clear()).called(1);
  });

  // testWidgets runs in fake time: tester.pump(duration) fires timers without waiting for real.
  testWidgets(
    'logs out with "session expired" when expiresAt passes while the app is open',
    (tester) async {
      when(() => storage.read()).thenAnswer(
        (_) async => StoredSession(
          accessToken: 'jwt',
          expiresAt: now.add(const Duration(minutes: 5)),
          user: user,
        ),
      );
      final container = createContainer();
      await container.read(authProvider.future);
      expect(container.read(authProvider).value, isA<Authenticated>());

      await tester.pump(const Duration(minutes: 4, seconds: 59));
      expect(container.read(authProvider).value, isA<Authenticated>());

      await tester.pump(const Duration(seconds: 1));
      expect(
        container.read(authProvider).value,
        isA<Unauthenticated>().having(
          (s) => s.reason,
          'reason',
          LogoutReason.sessionExpired,
        ),
      );
      verify(() => storage.clear()).called(1);
    },
  );
}
