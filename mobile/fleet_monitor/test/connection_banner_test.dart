import 'package:fleet_monitor/core/theme/app_theme.dart';
import 'package:fleet_monitor/shared/widgets/connection_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget banner) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Column(children: [banner])),
    ),
  );

  testWidgets('connected: nothing shown', (tester) async {
    await pump(
      tester,
      const ConnectionBanner(state: BannerConnectionState.connected),
    );

    expect(find.textContaining('Reconnecting'), findsNothing);
    expect(find.textContaining('Disconnected'), findsNothing);
  });

  testWidgets('reconnecting: slim banner, data may be outdated', (
    tester,
  ) async {
    await pump(
      tester,
      const ConnectionBanner(state: BannerConnectionState.reconnecting),
    );

    expect(find.text('Reconnecting…'), findsOneWidget);
    expect(find.text('Data may be outdated'), findsOneWidget);
  });

  testWidgets('disconnected: "paused since" + Retry calls back', (
    tester,
  ) async {
    var retries = 0;
    await pump(
      tester,
      ConnectionBanner(
        state: BannerConnectionState.disconnected,
        disconnectedSince: DateTime(2026, 11, 26, 14, 31),
        onRetry: () => retries++,
      ),
    );

    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Live updates paused since 14:31'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
