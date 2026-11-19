import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../identity/data/auth_providers.dart';
import 'roles_models.dart';
import 'roles_repository.dart';

/// My roles with their status, my applications, and how to earn a new role.
/// A role is earned: an application with documents, then a review.
class MyRolesScreen extends ConsumerWidget {
  const MyRolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes rôles')),
      body: SignedInGate(
        builder: (user) => RefreshIndicator(
          onRefresh: () async {
            // A decision may have changed the roles held: reload the session.
            ref
              ..invalidate(myRolesProvider)
              ..invalidate(authSessionProvider);
          },
          child: AsyncBody<MyRoles>(
            value: ref.watch(myRolesProvider),
            onRetry: () => ref.invalidate(myRolesProvider),
            builder: (roles) => _Body(roles: roles),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.roles});

  final MyRoles roles;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _starting = false;

  Future<void> _startCourier() async {
    setState(() => _starting = true);
    try {
      final application = await ref
          .read(rolesRepositoryProvider)
          .start('courier');
      ref.invalidate(myRolesProvider);
      if (mounted) {
        await context.push('/account/roles/applications/${application.id}');
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  /// Whether the account can apply for [role] now: it does not hold it (not
  /// even suspended) and no application is in progress.
  bool _canApply(String role) =>
      widget.roles.grantFor(role) == null &&
      widget.roles.openApplicationFor(role) == null;

  @override
  Widget build(BuildContext context) {
    final roles = widget.roles;
    final text = Theme.of(context).textTheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.space16),
      children: [
        SectionCard(
          title: 'Mes rôles',
          children: [
            for (final grant in roles.grants)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(grant.roleLabel),
                subtitle: grant.isActive || grant.statusReason.isEmpty
                    ? null
                    : Text(grant.statusReason),
                trailing: StatusStamp(grant.status, labels: roleStatusLabels),
              ),
            if (roles.grants.isEmpty) const Text('Aucun rôle pour le moment.'),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        if (roles.applications.isNotEmpty) ...[
          SectionCard(
            title: 'Mes candidatures',
            children: [
              for (final application in roles.applications)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    application.role == 'courier'
                        ? Icons.delivery_dining_outlined
                        : application.role == 'merchant'
                        ? Icons.storefront_outlined
                        : Icons.badge_outlined,
                  ),
                  title: Text(
                    application.shopName == null
                        ? application.roleLabel
                        : '${application.roleLabel} — ${application.shopName}',
                  ),
                  subtitle: Text(
                    [
                      if (application.invited) 'Sur invitation de l’équipe',
                      if (application.isEditable &&
                          application.reviewerMessage.isNotEmpty)
                        application.reviewerMessage,
                    ].join(' · '),
                  ),
                  trailing: StatusStamp(
                    application.status,
                    labels: roleStatusLabels,
                  ),
                  onTap: () => context.push(
                    '/account/roles/applications/${application.id}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
        ],
        if (_canApply('courier') || _canApply('merchant'))
          SectionCard(
            title: 'Obtenir un rôle',
            children: [
              Text(
                'Un rôle s’obtient sur dossier : vous envoyez les justificatifs '
                'demandés, l’équipe les examine, puis vous êtes prévenu de la '
                'décision.',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppSpacing.space8),
              Wrap(
                spacing: AppSpacing.space8,
                runSpacing: AppSpacing.space8,
                children: [
                  if (_canApply('merchant'))
                    OutlinedButton.icon(
                      onPressed: () => context.push('/merchant/orders'),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Ouvrir ma boutique'),
                    ),
                  if (_canApply('courier'))
                    FilledButton.icon(
                      onPressed: _starting ? null : _startCourier,
                      icon: const Icon(Icons.delivery_dining_outlined),
                      label: const Text('Devenir coursier'),
                    ),
                ],
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.space12),
        Text(
          'Les rôles de modérateur et d’agent support ne se demandent pas : '
          'l’équipe invite directement les personnes de confiance.',
          style: text.bodySmall,
        ),
      ],
    );
  }
}
