import 'package:flutter/material.dart';

import '../widgets/async_views.dart';
import 'upload_file.dart';

/// Picks a file then sends it; true once sent. A file the server would refuse
/// only shows why, and any other failure shows the API's message.
Future<bool> pickAndSendUpload(
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
