import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';
import 'commerce_models.dart';

/// What the payer's screen turns into a QR code.
class CashQr {
  const CashQr({required this.token, required this.expiresInSeconds});

  final String token;
  final int expiresInSeconds;

  factory CashQr.fromJson(Map<String, dynamic> json) => CashQr(
    token: json.requireString('token'),
    expiresInSeconds: json.intOrNull('expires_in') ?? 0,
  );
}

final cashRepositoryProvider = Provider<CashRepository>(
  (ref) => CashRepository(ref.watch(jsonApiProvider)),
);

/// Cash handed over by hand: the payer and the collector each confirm it, or
/// the payer shows a QR code that the collector scans (settles both at once).
class CashRepository {
  const CashRepository(this._api);

  final JsonApi _api;

  /// The payer: "I handed the money over".
  Future<Payment> payerConfirm(String number) =>
      _api.post('api/payments/$number/cash/payer-confirm/', Payment.fromJson);

  /// The collector (courier, or merchant at a pickup): "I received it".
  Future<Payment> collectorConfirm(String number) => _api.post(
    'api/payments/$number/cash/collector-confirm/',
    Payment.fromJson,
  );

  /// The collector: "nothing received". Opens a complaint at once.
  Future<Payment> collectorDeny(String number, String reason) => _api.post(
    'api/payments/$number/cash/collector-deny/',
    Payment.fromJson,
    data: {'reason': reason},
  );

  Future<CashQr> qr(String number) =>
      _api.getOne('api/payments/$number/cash/qr/', CashQr.fromJson);

  /// The collector scanned the payer's code.
  Future<Payment> scan(String token) => _api.post(
    'api/payments/cash/scan/',
    Payment.fromJson,
    data: {'token': token},
  );
}
