import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:frontend/core/network/json_api.dart';
import 'package:frontend/features/identity/data/auth_providers.dart';
import 'package:frontend/features/identity/models/auth_user.dart';

/// A status and a JSON body.
typedef FakeReply = ({int status, Object? body});

FakeReply ok(Object? body) => (status: 200, body: body);

/// A fake HTTP layer: answers every request with [handler] and records it, so
/// a test can check both what the screen shows and what it sent.
class FakeApi implements HttpClientAdapter {
  FakeApi(this.handler);

  final FakeReply Function(RequestOptions request) handler;
  final calls = <RequestOptions>[];

  JsonApi get jsonApi => JsonApi(
    Dio(BaseOptions(baseUrl: 'https://api.example.test/'))
      ..httpClientAdapter = this,
  );

  /// The requests sent with [method] to [path], oldest first.
  List<RequestOptions> sent(String method, String path) => [
    for (final call in calls)
      if (call.method == method && call.path == path) call,
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final reply = handler(options);
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A signed-in session, without touching the token storage.
class SignedInSession extends AuthSessionController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
    id: 1,
    email: 'client@demo.ga',
    displayName: 'Client',
    emailVerified: true,
  );
}

/// A visitor.
class VisitorSession extends AuthSessionController {
  @override
  Future<AuthUser?> build() async => null;
}

/// A product as the API lists it.
Map<String, Object?> productJson(
  int id,
  String name, {
  String? price,
  String currency = 'XAF',
}) => {
  'id': id,
  'name': name,
  'slug': 'produit-$id',
  'availability': 'available',
  'is_active': true,
  'is_verified': true,
  'price_snapshot': ?price,
  'price_snapshot_currency': price == null ? null : currency,
};
