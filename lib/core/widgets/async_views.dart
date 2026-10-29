import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/identity/data/auth_providers.dart';
import '../../features/identity/models/auth_user.dart';
import '../errors/api_exception.dart';
import '../theme/app_theme.dart';
import 'market_widgets.dart';

String errorText(
  Object error, [
  String fallback = 'Une erreur est survenue.',
]) => error is ApiException ? error.userMessage : fallback;

void showApiError(BuildContext context, Object error, [String? fallback]) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorText(error, fallback ?? 'Action impossible.'))),
  );
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Retour'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Loading / error (with retry) / data, scrollable so pull-to-refresh works.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
    this.errorFallback = 'Impossible de charger ces informations.',
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  final String errorFallback;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.space24),
        children: [
          const SizedBox(height: AppSpacing.space48),
          Text(errorText(error, errorFallback), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.space12),
          Center(
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ),
        ],
      ),
      data: builder,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.space24),
      children: [
        const SizedBox(height: AppSpacing.space48),
        Icon(icon, size: 48, color: AppColors.secondary),
        const SizedBox(height: AppSpacing.space12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.space8),
          Text(message!, textAlign: TextAlign.center),
        ],
        if (action != null) ...[
          const SizedBox(height: AppSpacing.space16),
          Center(child: action),
        ],
      ],
    );
  }
}

/// Shows [builder] for a signed-in user (optionally holding [role]),
/// otherwise a prompt to sign in or an access notice.
class SignedInGate extends ConsumerWidget {
  const SignedInGate({
    super.key,
    required this.builder,
    this.role,
    this.signInMessage = 'Connectez-vous pour accéder à cet espace.',
  });

  final Widget Function(AuthUser user) builder;
  final String? role;
  final String signInMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    return AsyncBody<AuthUser?>(
      value: session,
      onRetry: () => ref.invalidate(authSessionProvider),
      errorFallback: 'Impossible de vérifier votre compte.',
      builder: (user) {
        if (user == null) {
          return EmptyState(
            icon: Icons.lock_outline,
            title: signInMessage,
            action: FilledButton(
              onPressed: () => context.push('/auth'),
              child: const Text('Se connecter ou créer un compte'),
            ),
          );
        }
        if (role != null && !user.hasRole(role!)) {
          return const EmptyState(
            icon: Icons.block,
            title: 'Cet espace est réservé à un autre profil.',
          );
        }
        return builder(user);
      },
    );
  }
}

/// Status stamp with a French label and a tone per status family.
class StatusStamp extends StatelessWidget {
  const StatusStamp(this.status, {super.key, this.labels = const {}});

  final String status;
  final Map<String, String> labels;

  static const _positive = {
    'confirmed',
    'completed',
    'captured',
    'delivered',
    'collected',
    'ready',
    'accepted',
    'resolved',
    'available',
    'active',
    'verified',
    'sent',
    'read',
    'triggered',
    'located',
    'created',
  };
  static const _negative = {
    'cancelled',
    'failed',
    'declined',
    'rejected',
    'expired',
    'returned',
    'unavailable',
    'timeout',
    'closed',
    'suspended',
    'duplicate',
    'withdrawn',
    'dismissed',
  };

  @override
  Widget build(BuildContext context) {
    final color = _positive.contains(status)
        ? AppColors.primary
        : _negative.contains(status)
        ? AppColors.terracotta
        : AppColors.warning;
    return StampBadge(
      label: (labels[status] ?? commonStatusLabels[status] ?? status)
          .toUpperCase(),
      color: color,
    );
  }
}

const commonStatusLabels = {
  'pending': 'En attente',
  'paid': 'Payée',
  'confirmed': 'Confirmée',
  'completed': 'Terminée',
  'failed': 'Échouée',
  'cancelled': 'Annulée',
  'captured': 'Payé',
  'declined': 'Refusé',
  'timeout': 'Sans réponse',
  'refunded': 'Remboursé',
  'partial_refund': 'Remboursé en partie',
  'authorized': 'Autorisé',
  'assigned': 'Coursier assigné',
  'in_transit': 'En route',
  'delivered': 'Livrée',
  'returned': 'Retournée',
  'ready': 'Prête',
  'collected': 'Retirée',
  'expired': 'Expirée',
  'accepted': 'Acceptée',
  'rejected': 'Rejetée',
  'duplicate': 'Doublon',
  'open': 'Ouvert',
  'in_progress': 'En cours',
  'waiting_user': 'En attente de vous',
  'resolved': 'Résolu',
  'closed': 'Fermé',
  'under_review': 'En examen',
  'escalated': 'Escaladé',
  'pending_merchant': 'Attente marchand',
  'available': 'Disponible',
  'limited': 'Stock limité',
  'unavailable': 'Indisponible',
  'unknown': 'Inconnue',
  'discontinued': 'Arrêté',
  'draft': 'Brouillon',
  'review': 'En révision',
  'published': 'Publié',
  'suspended': 'Suspendu',
  'active': 'Active',
  'verified': 'Vérifié',
  'filed': 'Déposée',
  'withdrawn': 'Retirée',
  'triggered': 'Déclenchée',
  'paused': 'En pause',
  'dismissed': 'Écartée',
  'located': 'Localisé',
  'created': 'Créé',
};

String formatDateTime(DateTime? value) {
  if (value == null) {
    return '—';
  }
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}

/// Titled card section used by detail screens.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.space8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
