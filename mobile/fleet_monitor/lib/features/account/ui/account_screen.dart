import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/data/auth_models.dart';
import '../../vehicles/data/fleets_repository.dart';
import '../../vehicles/state/vehicle_list_notifier.dart';

/// Account (Account.dc.html): who is signed in, their role and fleets, and Log out.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider).value;
    if (auth is! Authenticated) return const Scaffold();
    final user = auth.user;
    final fleets = ref.watch(fleetsProvider);
    final vehicles = ref.watch(vehicleListProvider).value?.vehicles ?? const [];

    return Scaffold(
      appBar: const FleetAppBar(title: 'Account', showBack: true),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        InitialsAvatar(name: user.displayName, size: 64),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.displayName, style: AppText.titleLarge),
                              Text(
                                user.email,
                                style: AppText.labelLarge.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: AppPalette.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionTitle('Role'),
                    _Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.primary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.badge,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.shield_outlined,
                                    size: 16,
                                    color: AppPalette.onPrimary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _roleName(user.role),
                                    style: AppText.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppPalette.onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                user.role == Role.admin
                                    ? 'Sees every fleet in the organisation.'
                                    : 'Sees fleets assigned by an admin.',
                                style: AppText.bodyMedium.copyWith(
                                  color: AppPalette.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionTitle('Accessible fleets'),
                    _Card(
                      child: switch (fleets) {
                        AsyncData(:final value) when value.isEmpty =>
                          const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Text('No fleets assigned.'),
                          ),
                        AsyncData(:final value) => Column(
                          children: [
                            for (var i = 0; i < value.length; i++)
                              _FleetRow(
                                name: value[i].name,
                                meta:
                                    '${vehicles.where((v) => v.fleetId == value[i].id).length} vehicles · ${value[i].region}',
                                showTopBorder: i > 0,
                              ),
                          ],
                        ),
                        AsyncError() => const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Text('Couldn’t load fleets.'),
                        ),
                        _ => const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: LinearProgressIndicator(),
                        ),
                      },
                    ),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        key: const Key('accountLogout'),
                        onPressed: () => ref
                            .read(authProvider.notifier)
                            .logout(LogoutReason.userRequested),
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Log out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppPalette.error,
                          backgroundColor: AppPalette.surface,
                          side: const BorderSide(
                            color: AppPalette.error,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          textStyle: AppText.titleSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _roleName(Role role) => switch (role) {
    Role.admin => 'Admin',
    Role.operator => 'Operator',
    Role.unknown => 'User',
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: AppText.labelMedium.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppPalette.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: AppPalette.surface,
      border: Border.all(color: AppPalette.outlineVariant),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: child,
  );
}

class _FleetRow extends StatelessWidget {
  const _FleetRow({
    required this.name,
    required this.meta,
    required this.showTopBorder,
  });

  final String name;
  final String meta;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 64),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 10,
    ),
    decoration: BoxDecoration(
      border: showTopBorder
          ? const Border(top: BorderSide(color: AppPalette.divider))
          : null,
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppPalette.fleetIconBackground,
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          child: const Icon(
            Icons.home_work_outlined,
            size: 22,
            color: AppPalette.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                meta,
                style: AppText.bodyMedium.copyWith(
                  color: AppPalette.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
