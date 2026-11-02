import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';

/// A channel outside the app, and whether it is linked to the account.
class MessagingChannel {
  const MessagingChannel({
    required this.channel,
    required this.label,
    required this.isAvailable,
    this.linkId,
    this.linkStatus = '',
  });

  final String channel;
  final String label;

  /// False while the provider is not configured on the server.
  final bool isAvailable;
  final int? linkId;
  final String linkStatus;

  bool get isLinked => linkStatus == 'active';

  factory MessagingChannel.fromJson(Map<String, dynamic> json) {
    final link = json['link'];
    return MessagingChannel(
      channel: json.requireString('channel'),
      label: json.string('label'),
      isAvailable: json.flag('available'),
      linkId: link is Map<String, dynamic> ? link.intOrNull('id') : null,
      linkStatus: link is Map<String, dynamic> ? link.string('status') : '',
    );
  }
}

/// What the app needs to finish linking a channel.
class StartedChannelLink {
  const StartedChannelLink({
    required this.id,
    required this.code,
    required this.deepLink,
  });

  final int id;

  /// Empty for SMS: that code only reaches the phone.
  final String code;
  final String deepLink;

  factory StartedChannelLink.fromJson(Map<String, dynamic> json) =>
      StartedChannelLink(
        id: json.requireInt('id'),
        code: json.string('code'),
        deepLink: json.string('deep_link'),
      );
}

class ChannelPreferences {
  const ChannelPreferences({
    this.preferred = '',
    this.fallback = '',
    this.frequency = 'immediate',
    this.mutedTypes = const [],
  });

  final String preferred;
  final String fallback;
  final String frequency;
  final List<String> mutedTypes;

  factory ChannelPreferences.fromJson(Map<String, dynamic> json) {
    final muted = json['muted_types'];
    return ChannelPreferences(
      preferred: json.string('preferred_channel'),
      fallback: json.string('fallback_channel'),
      frequency: json.string('frequency', 'immediate'),
      mutedTypes: muted is List ? muted.whereType<String>().toList() : const [],
    );
  }
}

/// Alert types a user can mute, with their French labels.
const mutableNotificationTypes = {
  'price_alert': 'Alertes de prix',
  'price_drop': 'Baisses de prix',
  'back_in_stock': 'Retours en stock',
  'order_confirmed': 'Commandes confirmées',
  'order_shipped': 'Commandes en route',
  'order_delivered': 'Commandes livrées',
  'pickup_ready': 'Retraits disponibles',
  'payment_failed': 'Paiements refusés',
  'payment_refunded': 'Remboursements',
};

const notificationFrequencies = {
  'immediate': 'Dès que possible',
  'daily': 'Alertes de prix regroupées à 8 h',
};

final channelsRepositoryProvider = Provider<ChannelsRepository>(
  (ref) => ChannelsRepository(ref.watch(jsonApiProvider)),
);

final messagingChannelsProvider =
    FutureProvider.autoDispose<List<MessagingChannel>>(
      (ref) => ref.watch(channelsRepositoryProvider).getChannels(),
    );

final channelPreferencesProvider =
    FutureProvider.autoDispose<ChannelPreferences>(
      (ref) => ref.watch(channelsRepositoryProvider).getPreferences(),
    );

class ChannelsRepository {
  const ChannelsRepository(this._api);

  final JsonApi _api;

  Future<List<MessagingChannel>> getChannels() async =>
      await _api.getAll('api/messaging/channels/', MessagingChannel.fromJson);

  Future<StartedChannelLink> startLink(String channel, {String phone = ''}) =>
      _api.post(
        'api/messaging/links/',
        StartedChannelLink.fromJson,
        data: {'channel': channel, 'phone': phone},
      );

  Future<void> confirmSms(int linkId, String code) => _api.send(
    'api/messaging/links/$linkId/confirm/',
    data: {'code': code.trim()},
  );

  Future<void> unlink(int linkId) =>
      _api.delete('api/messaging/links/$linkId/');

  Future<ChannelPreferences> getPreferences() =>
      _api.getOne('api/messaging/preferences/', ChannelPreferences.fromJson);

  Future<ChannelPreferences> updatePreferences({
    String? preferred,
    String? fallback,
    String? frequency,
    List<String>? mutedTypes,
  }) => _api.patch(
    'api/messaging/preferences/',
    ChannelPreferences.fromJson,
    // Null leaves a field unchanged; an empty channel clears it.
    data: {
      'preferred_channel': preferred,
      'fallback_channel': fallback,
      'frequency': frequency,
      'muted_types': mutedTypes,
    },
  );
}
