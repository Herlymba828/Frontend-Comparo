import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/files/upload_file.dart';
import '../../core/files/upload_flow.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import '../roles/roles_models.dart';
import '../roles/roles_repository.dart';
import 'merchant_repository.dart';

/// The shop logo, shown to customers next to its offers.
class ShopLogoCard extends ConsumerWidget {
  const ShopLogoCard({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(merchantRepositoryProvider);
    final hasLogo = shop.logoUrl.isNotEmpty;
    return SectionCard(
      title: 'Logo',
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.space8),
              child: SizedBox.square(
                dimension: 72,
                child: hasLogo
                    ? Image.network(
                        shop.logoUrl,
                        fit: BoxFit.cover,
                        semanticLabel: 'Logo de ${shop.name}',
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image_outlined),
                      )
                    : const ColoredBox(
                        color: AppColors.kraft,
                        child: Icon(Icons.storefront_outlined, size: 32),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            const Expanded(
              child: Text(
                'Image JPEG ou PNG, carrée de préférence, 1 Mo au plus.',
              ),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.space8,
          children: [
            TextButton.icon(
              onPressed: () async {
                final sent = await pickAndSendUpload(
                  context,
                  allowPdf: false,
                  maxBytes: logoMaxBytes,
                  send: repository.uploadLogo,
                );
                if (sent) {
                  ref.invalidate(myShopProvider);
                }
              },
              icon: const Icon(Icons.upload_outlined),
              label: Text(hasLogo ? 'Changer' : 'Ajouter un logo'),
            ),
            if (hasLogo)
              TextButton.icon(
                onPressed: () async {
                  try {
                    await repository.removeLogo();
                    ref.invalidate(myShopProvider);
                  } catch (error) {
                    if (context.mounted) {
                      showApiError(context, error);
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Retirer'),
              ),
          ],
        ),
      ],
    );
  }
}

/// The shop's merchant application: its status, what the team asked, and the
/// way to complete and follow it. The documents are sent there, with the
/// other requirements of the role; the merchant role comes with the approval.
class ShopApplicationCard extends ConsumerWidget {
  const ShopApplicationCard({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final roles = ref.watch(myRolesProvider);
    return SectionCard(
      title: 'Candidature marchand',
      children: [
        roles.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => Row(
            children: [
              Expanded(child: Text(errorText(error))),
              TextButton(
                onPressed: () => ref.invalidate(myRolesProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
          data: (mine) {
            final application = mine.latestApplicationFor('merchant');
            if (shop.isVerified && application == null) {
              return const Text('Boutique vérifiée.');
            }
            if (application == null) {
              return const Text(
                'Aucune candidature pour cette boutique. Contactez l’aide.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('État du dossier')),
                    StatusStamp(application.status, labels: roleStatusLabels),
                  ],
                ),
                if (application.reviewerMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.space8),
                    child: Text(application.reviewerMessage),
                  ),
                const SizedBox(height: AppSpacing.space8),
                Text(
                  shop.isVerified
                      ? 'Boutique vérifiée : vos justificatifs sont conservés.'
                      : application.isEditable
                      ? 'Pièce d’identité, registre du commerce, numéro fiscal, '
                            'justificatif d’adresse, photo de la devanture : '
                            'envoyez-les puis soumettez votre dossier. Seuls vous '
                            'et l’équipe les voyez.'
                      : 'L’équipe examine votre dossier : vous serez prévenu '
                            'de la décision.',
                  style: text.bodySmall,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(
                      '/account/roles/applications/${application.id}',
                    ),
                    child: Text(
                      application.isEditable
                          ? 'Compléter mon dossier'
                          : 'Suivre mon dossier',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
