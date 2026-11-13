import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../network/json_api.dart';
import '../theme/app_theme.dart';
import '../widgets/async_views.dart';

/// True for the bytes of a PDF ("%PDF" header), whatever the file name.
bool isPdfBytes(List<int> bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x25 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x44 &&
    bytes[3] == 0x46;

/// Opens a private file (shop document, dispute evidence): downloaded with
/// the session, a picture is shown, a PDF is handed to the system to save
/// or open.
Future<void> openProtectedFile(
  BuildContext context,
  WidgetRef ref, {
  required String path,
  required String title,
}) async {
  final List<int> bytes;
  try {
    bytes = await ref.read(jsonApiProvider).getBytes(path);
  } catch (error) {
    if (context.mounted) {
      showApiError(context, error, 'Impossible d’ouvrir ce fichier.');
    }
    return;
  }
  final data = Uint8List.fromList(bytes);
  if (isPdfBytes(data)) {
    await SharePlus.instance.share(
      ShareParams(
        title: title,
        files: [
          XFile.fromData(
            data,
            mimeType: 'application/pdf',
            name: '${_fileName(title)}.pdf',
          ),
        ],
      ),
    );
    return;
  }
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space12),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          Flexible(
            child: InteractiveViewer(
              child: Image.memory(data, semanticLabel: title),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    ),
  );
}

String _fileName(String title) {
  final cleaned = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return cleaned.isEmpty ? 'document' : cleaned;
}
