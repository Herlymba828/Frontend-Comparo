import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../identity/data/auth_providers.dart';
import 'favorites_repository.dart';

/// The heart of a product: follows or unfollows it. A visitor is sent to the
/// sign-in screen first.
class FavoriteProductButton extends ConsumerWidget {
  const FavoriteProductButton({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followed =
        ref.watch(favoriteIdsProvider).value?.productIds.contains(productId) ??
        false;
    return _Heart(
      followed: followed,
      followLabel: 'Ajouter aux favoris',
      unfollowLabel: 'Retirer des favoris',
      followedMessage: 'Ajouté à vos favoris.',
      unfollowedMessage: 'Retiré de vos favoris.',
      toggle: (repository, follow) => follow
          ? repository.followProduct(productId)
          : repository.unfollowProduct(productId),
    );
  }
}

/// The heart of a shop, shown on its offers.
class FavoriteShopButton extends ConsumerWidget {
  const FavoriteShopButton({super.key, required this.merchantId});

  final int merchantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followed =
        ref
            .watch(favoriteIdsProvider)
            .value
            ?.merchantIds
            .contains(merchantId) ??
        false;
    return _Heart(
      followed: followed,
      followLabel: 'Suivre ce commerce',
      unfollowLabel: 'Ne plus suivre ce commerce',
      followedMessage: 'Commerce ajouté à vos favoris.',
      unfollowedMessage: 'Commerce retiré de vos favoris.',
      toggle: (repository, follow) => follow
          ? repository.followShop(merchantId)
          : repository.unfollowShop(merchantId),
    );
  }
}

class _Heart extends ConsumerStatefulWidget {
  const _Heart({
    required this.followed,
    required this.followLabel,
    required this.unfollowLabel,
    required this.followedMessage,
    required this.unfollowedMessage,
    required this.toggle,
  });

  final bool followed;
  final String followLabel;
  final String unfollowLabel;
  final String followedMessage;
  final String unfollowedMessage;
  final Future<void> Function(FavoritesRepository repository, bool follow)
  toggle;

  @override
  ConsumerState<_Heart> createState() => _HeartState();
}

class _HeartState extends ConsumerState<_Heart> {
  bool _busy = false;

  Future<void> _press() async {
    final user = await ref.read(authSessionProvider.future);
    if (!mounted) {
      return;
    }
    if (user == null) {
      await context.push('/auth');
      return;
    }
    setState(() => _busy = true);
    final follow = !widget.followed;
    try {
      await widget.toggle(ref.read(favoritesRepositoryProvider), follow);
      ref
        ..invalidate(favoriteIdsProvider)
        ..invalidate(favoriteProductsProvider)
        ..invalidate(favoriteShopsProvider);
      if (mounted) {
        showInfo(
          context,
          follow ? widget.followedMessage : widget.unfollowedMessage,
        );
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
    return IconButton(
      tooltip: widget.followed ? widget.unfollowLabel : widget.followLabel,
      onPressed: _busy ? null : _press,
      isSelected: widget.followed,
      icon: const Icon(Icons.favorite_border),
      selectedIcon: const Icon(Icons.favorite, color: AppColors.error),
    );
  }
}
