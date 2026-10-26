import 'package:flutter/material.dart';

import '../storage/repository_result.dart';
import '../theme/app_theme.dart';

class CacheStatusBanner extends StatelessWidget {
  const CacheStatusBanner({super.key, required this.result});

  final RepositoryResult<Object?> result;

  @override
  Widget build(BuildContext context) {
    if (!result.isFromCache) {
      return const SizedBox.shrink();
    }

    final cachedAt = result.cachedAtUtc!.toLocal();
    final cachedAtLabel =
        '${cachedAt.day.toString().padLeft(2, '0')}/${cachedAt.month.toString().padLeft(2, '0')}/${cachedAt.year} ${cachedAt.hour.toString().padLeft(2, '0')}:${cachedAt.minute.toString().padLeft(2, '0')}';
    final message = result.isExpired
        ? 'Copie locale du $cachedAtLabel. Cache expiré : ces données peuvent être anciennes et non vérifiées.'
        : 'Copie locale du $cachedAtLabel. Les prix peuvent différer de la situation actuelle.';
    final accent = result.isExpired ? AppColors.terracotta : AppColors.warning;

    return Semantics(
      container: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: result.isExpired
              ? Theme.of(context).colorScheme.errorContainer
              : AppColors.kraft,
          border: Border.all(color: accent, width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              result.isExpired ? Icons.warning_amber : Icons.cloud_off,
              size: 18,
              color: accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.ink, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
