import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A file chosen by the user, ready to send as multipart.
class UploadFile {
  const UploadFile({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  bool get isPdf => filename.toLowerCase().endsWith('.pdf');

  MultipartFile toMultipart() =>
      MultipartFile.fromBytes(bytes, filename: filename);
}

/// A chosen file the server would refuse (format or size).
class UploadRejected implements Exception {
  const UploadRejected(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Same limits as the server (UPLOAD_LOGO_MAX_BYTES and
/// UPLOAD_DOCUMENT_MAX_BYTES).
const logoMaxBytes = 1024 * 1024;
const documentMaxBytes = 5 * 1024 * 1024;

const _imageExtensions = ['jpg', 'jpeg', 'png'];

/// Checks what the server checks first, so the user learns it at once.
UploadFile checkUpload(
  UploadFile file, {
  required bool allowPdf,
  required int maxBytes,
}) {
  final name = file.filename.toLowerCase();
  final allowed = [..._imageExtensions, if (allowPdf) 'pdf'];
  if (!allowed.any((extension) => name.endsWith('.$extension'))) {
    throw UploadRejected(
      allowPdf
          ? 'Choisissez une photo JPEG ou PNG, ou un PDF.'
          : 'Choisissez une image JPEG ou PNG.',
    );
  }
  if (file.bytes.length > maxBytes) {
    final megabytes = maxBytes ~/ (1024 * 1024);
    throw UploadRejected('Fichier trop lourd ($megabytes Mo au plus).');
  }
  return file;
}

/// Asks where the file comes from (camera or files), then picks it. Null
/// when the user gives up.
Future<UploadFile?> pickUpload(
  BuildContext context, {
  required bool allowPdf,
  required int maxBytes,
}) async {
  final source = await showModalBottomSheet<_Source>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(context, _Source.camera),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: Text(
              allowPdf ? 'Choisir une image ou un PDF' : 'Choisir une image',
            ),
            onTap: () => Navigator.pop(context, _Source.files),
          ),
        ],
      ),
    ),
  );
  final file = switch (source) {
    null => null,
    _Source.camera => await _fromCamera(),
    _Source.files => await _fromFiles(allowPdf: allowPdf),
  };
  return file == null
      ? null
      : checkUpload(file, allowPdf: allowPdf, maxBytes: maxBytes);
}

enum _Source { camera, files }

Future<UploadFile?> _fromCamera() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    // Readable document, a few hundred KB instead of several MB.
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 80,
    requestFullMetadata: false,
  );
  if (file == null) {
    return null;
  }
  return UploadFile(bytes: await file.readAsBytes(), filename: file.name);
}

Future<UploadFile?> _fromFiles({required bool allowPdf}) async {
  final file = await openFile(
    acceptedTypeGroups: [
      XTypeGroup(
        label: allowPdf ? 'Images ou PDF' : 'Images',
        extensions: [..._imageExtensions, if (allowPdf) 'pdf'],
        mimeTypes: ['image/jpeg', 'image/png', if (allowPdf) 'application/pdf'],
        uniformTypeIdentifiers: [
          'public.jpeg',
          'public.png',
          if (allowPdf) 'com.adobe.pdf',
        ],
      ),
    ],
  );
  if (file == null) {
    return null;
  }
  return UploadFile(bytes: await file.readAsBytes(), filename: file.name);
}
