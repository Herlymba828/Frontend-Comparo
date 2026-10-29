import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_navigation_bar.dart';
import '../../core/widgets/async_views.dart';
import '../../core/widgets/space_scaffold.dart';
import '../identity/data/auth_providers.dart';
import '../identity/models/auth_user.dart';
import 'account_repository.dart';
import 'email_verification_dialog.dart';

/// Account hub: shopping, community and the spaces of the user's roles.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon compte'),
        actions: const [SpaceSwitcher(current: AppSpace.customer)],
      ),
      bottomNavigationBar: const AppNavigationBar(currentIndex: 3),
      body: SignedInGate(
        signInMessage:
            'Connectez-vous pour gérer vos commandes et votre compte.',
        builder: (user) => _AccountMenu(user: user),
      ),
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref
        .watch(notificationsProvider)
        .value
        ?.where((n) => n.isUnread)
        .length;
    Widget entry(
      IconData icon,
      String title,
      String path, {
      String? subtitle,
      Widget? trailing,
    }) => ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: () => context.push(path),
    );
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(user.displayName.isEmpty ? user.email : user.displayName),
          subtitle: Text(user.email),
        ),
        const Divider(),
        _Header('Mes achats'),
        entry(Icons.shopping_basket_outlined, 'Mon panier', '/cart'),
        entry(Icons.receipt_long_outlined, 'Mes commandes', '/orders'),
        entry(
          Icons.notifications_outlined,
          'Notifications',
          '/notifications',
          trailing: unread == null || unread == 0
              ? null
              : Badge(
                  label: Text('$unread'),
                  child: const Icon(Icons.chevron_right),
                ),
        ),
        entry(Icons.trending_down, 'Mes alertes de prix', '/alerts'),
        _Header('Communauté'),
        entry(
          Icons.add_a_photo_outlined,
          'Relevés de prix',
          '/contributions',
          subtitle: 'Partager un prix, vérifier ceux des autres',
        ),
        entry(Icons.support_agent, 'Aide et réclamations', '/support'),
        _Header('Mes espaces'),
        // Each role works in its own space (own screens and navigation).
        for (final space in spacesOf(user))
          if (space != AppSpace.customer)
            ListTile(
              leading: Icon(space.icon, color: AppColors.primary),
              title: Text(space.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(space.home),
            ),
        if (!AppSpace.merchant.isOpenTo(user))
          entry(
            Icons.add_business_outlined,
            'Ouvrir ma boutique',
            AppSpace.merchant.home,
            subtitle: 'Vendre et recevoir des commandes',
          ),
        _Header('Compte'),
        entry(
          Icons.manage_accounts_outlined,
          'Profil et sécurité',
          '/account/profile',
        ),
        ListTile(
          leading: const Icon(Icons.logout, color: AppColors.terracotta),
          title: const Text('Se déconnecter'),
          onTap: () async {
            final ok = await confirmAction(
              context,
              title: 'Se déconnecter ?',
              message:
                  'Vos données hors ligne seront effacées de cet appareil.',
              confirmLabel: 'Se déconnecter',
            );
            if (ok) {
              try {
                await ref.read(authSessionProvider.notifier).logout();
              } on Exception {
                // Offline: the device is signed out all the same; the
                // server session ends with its refresh token.
              }
            }
          },
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space16,
        AppSpacing.space16,
        AppSpacing.space16,
        AppSpacing.space4,
      ),
      child: Text(label, style: AppTextStyles.handNote),
    );
  }
}

// ── Profile & security ────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil et sécurité')),
      body: SignedInGate(builder: (user) => _ProfileBody(user: user)),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.user});

  final AuthUser user;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  late final _name = TextEditingController(text: widget.user.displayName);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _city = TextEditingController(text: widget.user.city);
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _city, _current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        showInfo(context, success);
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(accountRepositoryProvider);
    final sessions = ref.watch(sessionsProvider);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space16),
      children: [
        SectionCard(
          title: 'Mes informations',
          children: [
            InfoRow('E-mail', widget.user.email),
            if (!widget.user.emailVerified)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : () => verifyEmailFlow(context, ref),
                  icon: const Icon(Icons.mark_email_unread_outlined),
                  label: const Text('Vérifier mon adresse e-mail'),
                ),
              ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nom affiché'),
            ),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
            ),
            TextField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Ville'),
            ),
            const SizedBox(height: AppSpacing.space8),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      await repo.updateProfile(
                        displayName: _name.text.trim(),
                        phone: _phone.text.trim(),
                        city: _city.text.trim(),
                      );
                      ref.invalidate(authSessionProvider);
                    }, 'Profil mis à jour.'),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        SectionCard(
          title: 'Mot de passe',
          children: [
            TextField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe actuel',
              ),
            ),
            TextField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
              ),
            ),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmation'),
            ),
            const SizedBox(height: AppSpacing.space8),
            const Text(
              'Changer de mot de passe déconnecte tous vos appareils, '
              'y compris celui-ci : vous vous reconnecterez ensuite.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.space8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final router = GoRouter.of(context);
                      await repo.changePassword(
                        current: _current.text,
                        next: _next.text,
                        confirm: _confirm.text,
                      );
                      for (final c in [_current, _next, _confirm]) {
                        c.clear();
                      }
                      await ref
                          .read(authSessionProvider.notifier)
                          .endRevokedSession();
                      router.go('/auth');
                    }, 'Mot de passe modifié : reconnectez-vous.'),
              child: const Text('Changer le mot de passe'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        SectionCard(
          title: 'Appareils connectés',
          children: [
            sessions.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => Text(errorText(error)),
              data: (items) => Column(
                children: [
                  for (final session in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.devices_other),
                      title: Text(
                        session.device.isEmpty ? 'Appareil' : session.device,
                      ),
                      subtitle: Text(
                        'Actif le ${formatDateTime(session.lastActivity)}'
                        '${session.location.isEmpty ? '' : ' · ${session.location}'}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Déconnecter cet appareil',
                        icon: const Icon(Icons.logout),
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await repo.revokeSession(session.id);
                                ref.invalidate(sessionsProvider);
                              }, 'Appareil déconnecté.'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        SectionCard(
          title: 'Fermer mon compte',
          children: [
            const Text(
              'Vos informations personnelles sont effacées. Vos commandes '
              'et paiements restent conservés, sans votre nom, pour les '
              'obligations comptables. Une boutique liée est suspendue.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.space8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.terracotta,
              ),
              onPressed: _busy ? null : _closeAccount,
              child: const Text('Fermer mon compte'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _closeAccount() async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fermer définitivement le compte ?'),
        content: TextField(
          controller: password,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Mot de passe pour confirmer',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Fermer le compte'),
          ),
        ],
      ),
    );
    final secret = password.text;
    password.dispose();
    if (!(confirmed ?? false) || !mounted) {
      return;
    }
    final router = GoRouter.of(context);
    await _run(() async {
      await ref.read(accountRepositoryProvider).closeAccount(secret);
      await ref.read(authSessionProvider.notifier).endRevokedSession();
      router.go('/');
    }, 'Votre compte est fermé.');
  }
}

// ── Notifications ─────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(accountRepositoryProvider);
    Future<void> act(Future<void> Function() action) async {
      try {
        await action();
        ref.invalidate(notificationsProvider);
      } catch (error) {
        if (context.mounted) {
          showApiError(context, error);
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Tout marquer comme lu',
            icon: const Icon(Icons.done_all),
            onPressed: () => act(repo.markAllRead),
          ),
        ],
      ),
      body: SignedInGate(
        builder: (user) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(notificationsProvider),
          child: AsyncBody<List<AppNotification>>(
            value: ref.watch(notificationsProvider),
            onRetry: () => ref.invalidate(notificationsProvider),
            builder: (items) => items.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_none,
                    title: 'Aucune notification.',
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: Icon(
                          item.isUnread
                              ? Icons.mark_email_unread_outlined
                              : Icons.drafts_outlined,
                          color: item.isUnread
                              ? AppColors.terracotta
                              : AppColors.textSecondary,
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isUnread ? FontWeight.w700 : null,
                          ),
                        ),
                        subtitle: Text(
                          '${item.body}\n${formatDateTime(item.createdAt)}',
                        ),
                        isThreeLine: true,
                        onTap: item.isUnread
                            ? () => act(() => repo.markRead(item.id))
                            : null,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}
