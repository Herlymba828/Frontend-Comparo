import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/async_views.dart';
import 'account_repository.dart';

/// The photo is evidence for the check: downloaded with the session.
Future<void> showReportPhoto(
  BuildContext context,
  WidgetRef ref,
  Contribution item,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: FutureBuilder<List<int>>(
        future: ref
            .read(accountRepositoryProvider)
            .getReportPhoto(item.photoPath),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.space16),
              child: Text(errorText(snapshot.error!)),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.space24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return InteractiveViewer(
            child: Image.memory(
              Uint8List.fromList(bytes),
              semanticLabel: 'Photo du relevé : ${item.productName}',
            ),
          );
        },
      ),
    ),
  );
}
