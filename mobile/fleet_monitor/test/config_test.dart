import 'package:fleet_monitor/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid http URL is accepted', () {
    expect(AppConfig.parse('http://10.0.2.2:8080').apiBaseUrl.host, '10.0.2.2');
  });

  test('missing API_BASE_URL fails with instructions', () {
    expect(
      () => AppConfig.parse(''),
      throwsA(
        isA<ConfigException>().having(
          (e) => e.message,
          'message',
          contains('--dart-define=API_BASE_URL'),
        ),
      ),
    );
  });

  test('non-http value is rejected', () {
    expect(
      () => AppConfig.parse('localhost:8080'),
      throwsA(isA<ConfigException>()),
    );
  });
}
