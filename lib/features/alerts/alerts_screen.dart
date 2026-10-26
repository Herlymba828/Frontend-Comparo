import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/api_exception.dart';
import '../../core/formatters/price_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../identity/data/auth_providers.dart';
import 'data/alert_repository.dart';
import 'models/price_alert.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authSessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes alertes de prix'),
        actions: [
          IconButton(
            tooltip: 'Compte',
            onPressed: () => context.push('/auth'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: auth.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _AlertsError(
          message: error is ApiException
              ? error.userMessage
              : 'Impossible de vérifier votre compte.',
          onRetry: () => ref.invalidate(authSessionProvider),
        ),
        data: (user) => user == null
            ? _SignInPrompt(onSignIn: () => context.push('/auth'))
            : const _AlertList(),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.space12),
            Text(
              'Connectez-vous pour retrouver vos alertes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.space16),
            FilledButton(
              onPressed: onSignIn,
              child: const Text('Se connecter ou créer un compte'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertList extends ConsumerStatefulWidget {
  const _AlertList();

  @override
  ConsumerState<_AlertList> createState() => _AlertListState();
}

class _AlertListState extends ConsumerState<_AlertList> {
  final _busyIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(userAlertsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(userAlertsProvider),
      child: alerts.when(
        loading: () => ListView(
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
        error: (error, stackTrace) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.space24),
          children: [
            _AlertsError(
              message: error is ApiException
                  ? error.userMessage
                  : 'Impossible de charger vos alertes.',
              onRetry: () => ref.invalidate(userAlertsProvider),
            ),
          ],
        ),
        data: (items) => items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space24),
                children: [
                  const SizedBox(height: AppSpacing.space48),
                  const Icon(
                    Icons.notifications_none,
                    size: 48,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: AppSpacing.space12),
                  Text(
                    'Aucune alerte pour le moment.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  Text(
                    'Ouvrez une fiche produit et choisissez « Suivre le prix ».',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.space16),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.space8),
                itemBuilder: (context, index) => _AlertCard(
                  alert: items[index],
                  isBusy: _busyIds.contains(items[index].id),
                  onToggle: () => _updateAlert(items[index]),
                  onCancel: () => _confirmCancel(items[index]),
                ),
              ),
      ),
    );
  }

  Future<void> _updateAlert(PriceAlert alert) async {
    setState(() => _busyIds.add(alert.id));
    try {
      await ref
          .read(alertRepositoryProvider)
          .updateStatus(alertId: alert.id, resume: !alert.isActive);
      ref.invalidate(userAlertsProvider);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(alert.id));
      }
    }
  }

  Future<void> _confirmCancel(PriceAlert alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler cette alerte ?'),
        content: Text('L’alerte pour « ${alert.productName} » sera arrêtée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Garder'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler l’alerte'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _busyIds.add(alert.id));
    try {
      await ref.read(alertRepositoryProvider).cancelAlert(alert.id);
      ref.invalidate(userAlertsProvider);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(alert.id));
      }
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    final message = error is ApiException
        ? error.userMessage
        : 'Impossible de modifier cette alerte.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.isBusy,
    required this.onToggle,
    required this.onCancel,
  });

  final PriceAlert alert;
  final bool isBusy;
  final VoidCallback onToggle;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final threshold = alert.thresholdAmount == null
        ? null
        : formatPrice(alert.thresholdAmount, alert.thresholdCurrency);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.productName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.space4),
            Text(_triggerLabel(alert.triggerType)),
            if (threshold != null) ...[
              const SizedBox(height: AppSpacing.space4),
              Text(
                'Seuil : $threshold',
                style: AppTextStyles.priceSecondary.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.space8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _statusLabel(alert.status, alert.triggerCount),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (isBusy)
                  const SizedBox(
                    width: AppSpacing.space24,
                    height: AppSpacing.space24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  if (alert.status == 'active' || alert.status == 'paused')
                    IconButton(
                      tooltip: alert.isActive ? 'Mettre en pause' : 'Reprendre',
                      onPressed: onToggle,
                      icon: Icon(
                        alert.isActive ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                  if (alert.status != 'cancelled' && alert.status != 'expired')
                    IconButton(
                      tooltip: 'Annuler l’alerte',
                      onPressed: onCancel,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _triggerLabel(String triggerType) => switch (triggerType) {
    'price_drop' => 'Baisse de prix sous le seuil',
    'price_target' => 'Prix cible atteint',
    'back_in_stock' => 'Retour en stock',
    'new_offer' => 'Nouvelle offre disponible',
    'price_change' => 'Tout changement de prix',
    _ => triggerType.replaceAll('_', ' '),
  };

  String _statusLabel(String status, int triggerCount) {
    final label = switch (status) {
      'active' => 'Active',
      'paused' => 'En pause',
      'triggered' => 'Déclenchée',
      'expired' => 'Expirée',
      'cancelled' => 'Annulée',
      _ => status,
    };
    return triggerCount == 0
        ? label
        : '$label · $triggerCount déclenchement(s)';
  }
}

class _AlertsError extends StatelessWidget {
  const _AlertsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.space12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
      ],
    );
  }
}
