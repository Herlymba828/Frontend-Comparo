import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/account/channels_repository.dart';
import 'package:frontend/features/alerts/create_price_alert_dialog.dart';
import 'package:frontend/features/catalog/models/catalog_product.dart';
import 'package:frontend/features/product/product_share.dart';

void main() {
  shareTests();

  test('an alert always stays in the app, plus the picked channel', () {
    expect(alertNotifyChannels(''), ['in_app']);
    expect(alertNotifyChannels('telegram'), ['in_app', 'telegram']);
  });

  group('MessagingChannel', () {
    test('a channel is linked only once its link is active', () {
      final pending = MessagingChannel.fromJson({
        'channel': 'telegram',
        'label': 'Telegram',
        'available': true,
        'link': {'id': 3, 'status': 'pending'},
      });
      expect(pending.isLinked, isFalse);
      expect(pending.linkId, 3);

      final active = MessagingChannel.fromJson({
        'channel': 'sms',
        'label': 'SMS',
        'available': true,
        'link': {'id': 4, 'status': 'active'},
      });
      expect(active.isLinked, isTrue);
    });

    test('a channel without credentials is not available', () {
      final channel = MessagingChannel.fromJson({
        'channel': 'whatsapp',
        'label': 'WhatsApp',
        'available': false,
        'link': null,
      });
      expect(channel.isAvailable, isFalse);
      expect(channel.linkId, isNull);
    });
  });

  test('preferences keep the muted types and default to immediate', () {
    final preferences = ChannelPreferences.fromJson({
      'preferred_channel': 'telegram',
      'fallback_channel': '',
      'muted_types': ['price_drop'],
    });
    expect(preferences.preferred, 'telegram');
    expect(preferences.frequency, 'immediate');
    expect(preferences.mutedTypes, ['price_drop']);
  });

  test('a started link never needs a code for SMS', () {
    final started = StartedChannelLink.fromJson({
      'id': 9,
      'code': '',
      'deep_link': '',
    });
    expect(started.code, isEmpty);
  });
}

CatalogProduct _product({String? price}) => CatalogProduct(
  id: 1,
  name: 'Riz 1 kg',
  slug: 'riz',
  availability: 'available',
  isActive: true,
  isVerified: true,
  priceSnapshot: price,
  priceSnapshotCurrency: 'XAF',
);

void shareTests() {
  test('the shared text carries the known best price', () {
    final text = productShareText(_product(price: '1250'));
    expect(text, contains('Riz 1 kg'));
    expect(text, contains('meilleur prix connu'));
    expect(text, contains('250'));
  });

  test('a product without price is shared without any amount', () {
    final text = productShareText(_product());
    expect(text, isNot(contains('meilleur prix')));
    expect(text, contains('Riz 1 kg'));
  });
}
