import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/space_scaffold.dart';
import 'package:frontend/features/account/account_repository.dart';
import 'package:frontend/features/courier/courier_shell.dart';
import 'package:frontend/features/identity/models/auth_user.dart';
import 'package:frontend/features/merchant/merchant_shell.dart';
import 'package:frontend/features/moderation/moderation_screen.dart';

AuthUser _user(List<String> roles) => AuthUser(
  id: 1,
  email: 'a@demo.ga',
  displayName: 'A',
  emailVerified: true,
  roles: roles,
);

Contribution _report({required int confirmations, int rejections = 0}) =>
    Contribution(
      id: 1,
      productName: 'Riz',
      price: '700',
      currency: 'XAF',
      quantity: '1',
      unit: 'kg',
      location: '',
      status: 'pending',
      observedAt: null,
      confirmations: confirmations,
      rejections: rejections,
      required: 3,
      rejectionReason: '',
    );

void main() {
  group('spacesOf', () {
    test('a customer only has the customer space', () {
      expect(spacesOf(_user(['consumer'])), [AppSpace.customer]);
    });

    test('each role opens its own space', () {
      expect(spacesOf(_user(['consumer', 'merchant', 'courier'])), [
        AppSpace.customer,
        AppSpace.merchant,
        AppSpace.courier,
      ]);
      expect(spacesOf(_user(['moderator'])), [
        AppSpace.customer,
        AppSpace.moderation,
      ]);
    });

    test('admins enter the moderation space, like in the API', () {
      expect(AppSpace.moderation.isOpenTo(_user(['admin'])), isTrue);
      expect(AppSpace.merchant.isOpenTo(_user(['admin'])), isFalse);
    });
  });

  group('spaceTabIndex', () {
    test('selects the tab of the current location', () {
      expect(spaceTabIndex(merchantTabs, '/merchant/stock'), 2);
      expect(spaceTabIndex(courierTabs, '/courier/profile'), 2);
      expect(spaceTabIndex(moderationTabs, '/moderation/decided'), 1);
    });

    test('falls back to the first tab for an unknown location', () {
      expect(spaceTabIndex(merchantTabs, '/merchant'), 0);
    });

    test('does not confuse a tab with a longer path sharing its prefix', () {
      const tabs = [
        SpaceTab('A', Icons.abc, '/x/a'),
        SpaceTab('B', Icons.abc, '/x/ab'),
      ];
      expect(spaceTabIndex(tabs, '/x/ab'), 1);
    });
  });

  group('isReadyToPublish', () {
    test('needs the required confirmations', () {
      expect(isReadyToPublish(_report(confirmations: 2)), isFalse);
      expect(isReadyToPublish(_report(confirmations: 3)), isTrue);
    });

    test('needs more confirmations than contestations', () {
      expect(
        isReadyToPublish(_report(confirmations: 3, rejections: 3)),
        isFalse,
      );
    });
  });

  test('a complaint detail carries the merchant answer', () {
    final complaint = Complaint.fromJson({
      'id': 4,
      'complaint_number': 'CMP-1',
      'subject': 'Trop payé',
      'complaint_type': 'overcharge',
      'status': 'under_review',
      'filed_at': '2026-10-28T10:00:00Z',
      'is_open': true,
      'description': 'Montant facturé supérieur.',
      'merchant_response': 'Erreur de caisse, remboursée.',
      'responded_at': '2026-10-28T12:00:00Z',
    });
    expect(complaint.description, 'Montant facturé supérieur.');
    expect(complaint.merchantResponse, 'Erreur de caisse, remboursée.');
    expect(complaint.respondedAt, isNotNull);
    expect(complaintTypeLabels[complaint.type], 'Surfacturation');
  });
}
