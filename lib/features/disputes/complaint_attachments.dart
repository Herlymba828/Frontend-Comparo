import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files/protected_file.dart';
import '../../core/files/upload_file.dart';
import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import '../../core/widgets/async_views.dart';

/// Evidence added to a complaint (receipt, photo of the label), by a party
/// or an agent.
class ComplaintAttachment {
  const ComplaintAttachment({
    required this.id,
    required this.description,
    required this.downloadUrl,
    required this.isMine,
    this.createdAt,
  });

  final int id;
  final String description;
  final String downloadUrl;
  final bool isMine;
  final DateTime? createdAt;

  factory ComplaintAttachment.fromJson(Map<String, dynamic> json) =>
      ComplaintAttachment(
        id: json.requireInt('id'),
        description: json.string('description'),
        downloadUrl: json.string('download_url'),
        isMine: json.flag('is_mine'),
        createdAt: json.dateOrNull('created_at'),
      );
}

/// Same limit as the server (MAX_ATTACHMENTS).
const maxComplaintAttachments = 10;

final complaintAttachmentsProvider = FutureProvider.autoDispose
    .family<List<ComplaintAttachment>, int>(
      (ref, complaintId) => ref
          .watch(jsonApiProvider)
          .getAll(
            'api/disputes/$complaintId/attachments/',
            ComplaintAttachment.fromJson,
          ),
    );

/// The evidence of a complaint; new pieces while it is still examined.
class ComplaintAttachmentsCard extends ConsumerStatefulWidget {
  const ComplaintAttachmentsCard({
    super.key,
    required this.complaintId,
    required this.isOpen,
  });

  final int complaintId;
  final bool isOpen;

  @override
  ConsumerState<ComplaintAttachmentsCard> createState() =>
      _ComplaintAttachmentsCardState();
}

class _ComplaintAttachmentsCardState
    extends ConsumerState<ComplaintAttachmentsCard> {
  bool _busy = false;

  Future<void> _add() async {
    final UploadFile? file;
    try {
      file = await pickUpload(
        context,
        allowPdf: true,
        maxBytes: documentMaxBytes,
      );
    } on UploadRejected catch (rejected) {
      if (mounted) {
        showInfo(context, rejected.message);
      }
      return;
    }
    if (file == null || !mounted) {
      return;
    }
    final description = await _askDescription(context);
    if (description == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(jsonApiProvider)
          .postForm(
            'api/disputes/${widget.complaintId}/attachments/',
            (json) => json,
            fields: {'description': description},
            files: {'file': file.toMultipart()},
          );
      ref.invalidate(complaintAttachmentsProvider(widget.complaintId));
      if (mounted) {
        showInfo(context, 'Pièce ajoutée au dossier.');
      }
    } catch (error) {
      if (mounted) {
        showApiError(context, error, 'Envoi impossible.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = complaintAttachmentsProvider(widget.complaintId);
    final attachments = ref.watch(provider);
    final count = attachments.value?.length ?? 0;
    final canAdd = widget.isOpen && !_busy && count < maxComplaintAttachments;
    return SectionCard(
      title: 'Pièces du dossier',
      trailing: widget.isOpen
          ? IconButton(
              tooltip: 'Ajouter une pièce',
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file),
              onPressed: canAdd ? _add : null,
            )
          : null,
      children: [
        attachments.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => Text(errorText(error)),
          data: (items) => items.isEmpty
              ? Text(
                  widget.isOpen
                      ? 'Ticket de caisse, photo de l’étiquette : ajoutez ce '
                            'qui appuie le dossier (photo ou PDF, 5 Mo au plus).'
                      : 'Aucune pièce.',
                )
              : Column(
                  children: [
                    for (final (index, item) in items.indexed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(
                          item.description.isEmpty
                              ? 'Pièce ${index + 1}'
                              : item.description,
                        ),
                        subtitle: Text(
                          '${item.isMine ? 'Ajoutée par vous' : 'Ajoutée par l’autre partie ou l’équipe'}'
                          ' · ${formatDateTime(item.createdAt)}',
                        ),
                        onTap: () => openProtectedFile(
                          context,
                          ref,
                          path: item.downloadUrl,
                          title: item.description.isEmpty
                              ? 'Pièce ${index + 1}'
                              : item.description,
                        ),
                      ),
                    if (widget.isOpen && count >= maxComplaintAttachments)
                      Text(
                        '$maxComplaintAttachments pièces au plus par dossier.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// A short caption for the piece; null when the user cancels.
Future<String?> _askDescription(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Décrire la pièce'),
      content: TextField(
        controller: controller,
        maxLength: 255,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Description (facultative)',
          hintText: 'Ticket de caisse du 3 novembre',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Envoyer'),
        ),
      ],
    ),
  );
}
