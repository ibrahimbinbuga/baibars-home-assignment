import 'package:fleet_monitor/core/theme/app_theme.dart';
import 'package:fleet_monitor/features/vehicles/domain/display_status.dart';
import 'package:fleet_monitor/shared/widgets/status_badge.dart';
import 'package:fleet_monitor/shared/widgets/status_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final status in DisplayStatus.values) {
    for (final size in BadgeSize.values) {
      testWidgets('${status.name} (${size.name}) shows its label and icon, not only a colour', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: Center(child: StatusBadge(status: status, size: size))),
        ));

        expect(find.text(status.label), findsOneWidget);
        expect(find.byIcon(status.icon), findsOneWidget);
      });
    }
  }

  test('every status has a distinct label and icon', () {
    expect(DisplayStatus.values.map((s) => s.label).toSet(), hasLength(DisplayStatus.values.length));
    expect(DisplayStatus.values.map((s) => s.icon).toSet(), hasLength(DisplayStatus.values.length));
  });
}
