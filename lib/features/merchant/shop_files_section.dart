import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files/protected_file.dart';
import '../../core/files/upload_file.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import 'merchant_repository.dart';

/// Picks a file then sends it; a refused file only shows why.
Future<bool> _pickAndSend(
  BuildContext context, {
  required bool allowPdf,
  required int maxBytes,
  required Future<void> Function(UploadFile file) send,
}) async {
  try {
    final file = await pickUpload(
      context,
      allowPdf: allowPdf,
      maxBytes: maxBytes,
    );
    if (file == null) {
      return false;
    }
    await send(file);
    return true;
  } on UploadRejected catch (rejected) {
    if (context.mounted) {
      showInfo(context, rejected.message);
    }
  } catch (error) {
    if (context.mounted) {
      showApiError(context, error, 'Envoi impossible.');
    }
  }
  return false;
}

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
                final sent = await _pickAndSend(
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

/// Documents the moderators check before verifying the shop.
class ShopDocumentsCard extends ConsumerWidget {
  const ShopDocumentsCard({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(shopDocumentsProvider);
    final repository = ref.read(merchantRepositoryProvider);
    return SectionCard(
      title: 'Justificatifs',
      trailing: IconButton(
        tooltip: 'Envoyer un justificatif',
        icon: const Icon(Icons.note_add_outlined),
        onPressed: () async {
          final kind = await _chooseKind(context);
          if (kind == null || !context.mounted) {
            return;
          }
          final sent = await _pickAndSend(
            context,
            allowPdf: true,
            maxBytes: documentMaxBytes,
            send: (file) => repository.addDocument(kind, file),
          );
          if (sent) {
            ref.invalidate(shopDocumentsProvider);
            if (context.mounted) {
              showInfo(context, 'Justificatif envoyé à la modération.');
            }
          }
        },
      ),
      children: [
        Text(
          shop.isVerified
              ? 'Boutique vérifiée : vos justificatifs sont conservés.'
              : 'Pièce d’identité, registre du commerce, numéro fiscal : '
                    'la modération les examine pour vérifier la boutique. '
                    'Photo ou PDF, 5 Mo au plus. Seuls vous et la modération '
                    'les voyez.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        documents.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => Text(errorText(error)),
          data: (items) => items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.space8),
                  child: Text('Aucun justificatif envoyé.'),
                )
              : Column(
                  children: [
                    for (final document in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined),
                        title: Text(document.kindLabel),
                        subtitle: Text(
                          'Envoyé le ${formatDateTime(document.createdAt)}',
                        ),
                        onTap: () => openProtectedFile(
                          context,
                          ref,
                          path: document.downloadUrl,
                          title: document.kindLabel,
                        ),
                        trailing: shop.isVerified
                            ? null
                            : IconButton(
                                tooltip: 'Supprimer ce justificatif',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final ok = await confirmAction(
                                    context,
                                    title: 'Supprimer ce justificatif ?',
                                    message: document.kindLabel,
                                    confirmLabel: 'Supprimer',
                                  );
                                  if (!ok) {
                                    return;
                                  }
                                  try {
                                    await repository.deleteDocument(
                                      document.id,
                                    );
                                    ref.invalidate(shopDocumentsProvider);
                                  } catch (error) {
                                    if (context.mounted) {
                                      showApiError(context, error);
                                    }
                                  }
                                },
                              ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

Future<String?> _chooseKind(BuildContext context) => showDialog<String>(
  context: context,
  builder: (context) => SimpleDialog(
    title: const Text('Quel justificatif ?'),
    children: [
      for (final entry in shopDocumentKinds.entries)
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, entry.key),
          child: Text(entry.value),
        ),
    ],
  ),
);
