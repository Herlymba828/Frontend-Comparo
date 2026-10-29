import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/api_exception.dart';
import 'api_providers.dart';

final jsonApiProvider = Provider<JsonApi>(
  (ref) => JsonApi(ref.watch(apiClientProvider)),
);

/// One page of a DRF paginated list (`count`, `next`, `results`).
class Paged<T> {
  const Paged({
    required this.items,
    required this.count,
    required this.hasNext,
  });

  final List<T> items;
  final int count;
  final bool hasNext;
}

typedef JsonDecoder<T> = T Function(Map<String, dynamic> json);

/// Thin JSON layer over the shared [Dio] client: every failure (network,
/// HTTP error, unexpected payload) surfaces as an [ApiException].
class JsonApi {
  const JsonApi(this._client);

  final Dio _client;

  Future<T> getOne<T>(
    String path,
    JsonDecoder<T> decode, {
    Map<String, Object?>? query,
  }) => _guard(() async {
    final response = await _client.get<dynamic>(
      path,
      queryParameters: _clean(query),
    );
    return decode(_map(response.data));
  });

  /// A paginated list; also accepts a bare JSON array.
  Future<Paged<T>> getPage<T>(
    String path,
    JsonDecoder<T> decode, {
    Map<String, Object?>? query,
  }) => _guard(() async {
    final response = await _client.get<dynamic>(
      path,
      queryParameters: _clean(query),
    );
    final data = response.data;
    if (data is List) {
      final items = data.map((item) => decode(_map(item))).toList();
      return Paged(items: items, count: items.length, hasNext: false);
    }
    final map = _map(data);
    final results = map['results'];
    if (results is! List) {
      throw const FormatException('Paginated response without results.');
    }
    final items = results.map((item) => decode(_map(item))).toList();
    final count = map['count'];
    return Paged(
      items: items,
      count: count is int ? count : items.length,
      hasNext: map['next'] != null,
    );
  });

  /// Every item of a paginated list, page after page (at most [maxPages]
  /// pages of 100): screens no longer stop silently at the first page.
  Future<List<T>> getAll<T>(
    String path,
    JsonDecoder<T> decode, {
    Map<String, Object?>? query,
    int maxPages = 10,
  }) async {
    final items = <T>[];
    for (var page = 1; page <= maxPages; page++) {
      final result = await getPage(
        path,
        decode,
        query: {...?query, 'page_size': 100, 'page': page},
      );
      items.addAll(result.items);
      if (!result.hasNext) {
        break;
      }
    }
    return items;
  }

  Future<T> post<T>(
    String path,
    JsonDecoder<T> decode, {
    Map<String, Object?>? data,
  }) => _guard(() async {
    final response = await _client.post<dynamic>(path, data: _clean(data));
    return decode(_map(response.data));
  });

  /// Multipart POST (form fields plus files); null fields are omitted.
  Future<T> postForm<T>(
    String path,
    JsonDecoder<T> decode, {
    required Map<String, Object?> fields,
    Map<String, MultipartFile> files = const {},
  }) => _guard(() async {
    final form = FormData.fromMap({
      for (final entry in _clean(fields)!.entries)
        entry.key: entry.value.toString(),
      ...files,
    });
    final response = await _client.post<dynamic>(path, data: form);
    return decode(_map(response.data));
  });

  /// PATCH; a null value is dropped (field left unchanged) unless its key
  /// is in [clearable], where null means "empty this field".
  Future<T> patch<T>(
    String path,
    JsonDecoder<T> decode, {
    Map<String, Object?>? data,
    Set<String> clearable = const {},
  }) => _guard(() async {
    final response = await _client.patch<dynamic>(
      path,
      data: _clean(data, keep: clearable),
    );
    return decode(_map(response.data));
  });

  /// Raw bytes of an authenticated file (a report photo).
  Future<List<int>> getBytes(String path) => _guard(() async {
    final response = await _client.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty file.');
    }
    return data;
  });

  /// POST whose response body is not needed.
  Future<void> send(String path, {Map<String, Object?>? data}) =>
      _guard(() async {
        await _client.post<dynamic>(path, data: _clean(data));
      });

  Future<void> delete(String path) => _guard(() async {
    await _client.delete<dynamic>(path);
  });

  /// DELETE with a JSON body (a confirmation such as a password).
  Future<void> deleteWith(String path, {required Map<String, Object?> data}) =>
      _guard(() async {
        await _client.delete<dynamic>(path, data: data);
      });

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on FormatException {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    } on TypeError {
      throw const ApiException(kind: ApiErrorKind.invalidResponse);
    }
  }

  static Map<String, dynamic> _map(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const FormatException('JSON object expected.');
  }

  /// Drops null values: optional fields are omitted rather than sent as null
  /// (except the [keep] keys, whose null is meaningful).
  static Map<String, Object?>? _clean(
    Map<String, Object?>? values, {
    Set<String> keep = const {},
  }) => values == null
      ? null
      : {
          for (final entry in values.entries)
            if (entry.value != null || keep.contains(entry.key))
              entry.key: entry.value,
        };
}
