import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/core/files/protected_file.dart';
import 'package:frontend/core/files/upload_file.dart';
import 'package:frontend/features/disputes/complaint_attachments.dart';
import 'package:frontend/features/merchant/merchant_repository.dart';

UploadFile _file(String name, int size) =>
    UploadFile(bytes: Uint8List(size), filename: name);

void main() {
  group('checkUpload', () {
    test('a logo must be a JPEG or PNG picture', () {
      expect(
        () => checkUpload(
          _file('statuts.pdf', 10),
          allowPdf: false,
          maxBytes: logoMaxBytes,
        ),
        throwsA(
          isA<UploadRejected>().having(
            (rejected) => rejected.message,
            'message',
            contains('JPEG ou PNG'),
          ),
        ),
      );
      expect(
        checkUpload(
          _file('Logo.PNG', 10),
          allowPdf: false,
          maxBytes: logoMaxBytes,
        ).filename,
        'Logo.PNG',
      );
    });

    test('documents accept a PDF within the size limit', () {
      final pdf = checkUpload(
        _file('rccm.pdf', 1000),
        allowPdf: true,
        maxBytes: documentMaxBytes,
      );
      expect(pdf.isPdf, isTrue);
      expect(
        () => checkUpload(
          _file('notes.txt', 10),
          allowPdf: true,
          maxBytes: documentMaxBytes,
        ),
        throwsA(isA<UploadRejected>()),
      );
    });

    test('a file over the limit is refused before sending', () {
      expect(
        () => checkUpload(
          _file('photo.jpg', logoMaxBytes + 1),
          allowPdf: false,
          maxBytes: logoMaxBytes,
        ),
        throwsA(
          isA<UploadRejected>().having(
            (rejected) => rejected.message,
            'message',
            contains('1 Mo'),
          ),
        ),
      );
    });
  });

  test('a PDF is recognised from its bytes, not its name', () {
    expect(isPdfBytes('%PDF-1.4'.codeUnits), isTrue);
    expect(isPdfBytes([0x89, 0x50, 0x4E, 0x47]), isFalse);
    expect(isPdfBytes([0x25]), isFalse);
  });

  test('the shop reads its logo and its documents', () {
    final shop = Shop.fromJson({
      'id': 3,
      'name': 'Épicerie',
      'logo_url': 'https://api.example.test/api/merchants/3/logo/',
    });
    expect(shop.logoUrl, endsWith('/api/merchants/3/logo/'));
    expect(Shop.fromJson({'id': 4}).logoUrl, isEmpty);

    final document = ShopDocument.fromJson({
      'id': 9,
      'kind': 'tax',
      'download_url': '/api/merchants/3/documents/9/file/',
      'created_at': '2026-11-07T10:00:00Z',
    });
    expect(document.kindLabel, 'Numéro fiscal (NIF)');
    expect(document.downloadUrl, '/api/merchants/3/documents/9/file/');
  });

  test('a complaint piece says who added it', () {
    final piece = ComplaintAttachment.fromJson({
      'id': 2,
      'description': 'Ticket',
      'download_url': '/api/disputes/5/attachments/2/file/',
      'is_mine': true,
    });
    expect(piece.isMine, isTrue);
    expect(piece.description, 'Ticket');
  });

  group('error messages', () {
    ApiException fromResponse(int status, Object data, {String? retryAfter}) =>
        ApiException.fromDio(
          DioException(
            requestOptions: RequestOptions(path: 'x'),
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: RequestOptions(path: 'x'),
              statusCode: status,
              data: data,
              headers: Headers.fromMap({
                if (retryAfter != null) 'retry-after': [retryAfter],
              }),
            ),
          ),
        );

    test('the reset lock explains how long to wait', () {
      final locked = fromResponse(429, {
        'detail': 'Trop d’essais : demandez un nouveau code dans une heure.',
      });
      expect(locked.userMessage, contains('dans une heure'));
    });

    test('a throttled request still gives the waiting time', () {
      final throttled = fromResponse(429, {
        'detail': 'Request was throttled.',
      }, retryAfter: '30');
      expect(throttled.userMessage, 'Trop de demandes : réessayez dans 30 s.');
    });

    test('a refused file shows the server reason', () {
      final refused = fromResponse(400, {
        'error': {
          'detail': 'La requête est invalide.',
          'fields': {
            'file': ['Ce PDF contient du contenu actif : il est refusé.'],
          },
        },
      });
      expect(refused.userMessage, contains('contenu actif'));
    });
  });
}
