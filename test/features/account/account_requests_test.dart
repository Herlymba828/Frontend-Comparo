import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/errors/api_exception.dart';
import 'package:frontend/features/account/account_repository.dart';

import '../../support/fake_api.dart';

Map<String, Object?> _ticket() => {
  'id': 8,
  'ticket_number': 'TCK-8',
  'subject': 'Paiement absent',
  'category': 'payment',
  'status': 'open',
  'priority': 'normal',
  'is_open': true,
  'messages': <Object?>[],
};

void main() {
  test('the profile and the password reach their routes', () async {
    final api = FakeApi((_) => ok(<String, Object?>{}));
    final repo = AccountRepository(api.jsonApi);

    await repo.updateProfile(
      displayName: 'Awa Ndong',
      phone: '+24106000000',
      city: 'Libreville',
    );
    await repo.changePassword(
      current: 'ancien',
      next: 'nouveau-Mot2Passe!',
      confirm: 'nouveau-Mot2Passe!',
    );

    expect(api.sent('PATCH', 'api/auth/me/').single.data, {
      'display_name': 'Awa Ndong',
      'phone': '+24106000000',
      'city': 'Libreville',
    });
    final password = api.sent('POST', 'api/auth/password/change/').single;
    expect((password.data as Map)['new_password'], 'nouveau-Mot2Passe!');
    expect(
      (password.data as Map)['new_password_confirm'],
      'nouveau-Mot2Passe!',
    );
  });

  test(
    'closing the account asks for the password in the request body',
    () async {
      final api = FakeApi((_) => ok(<String, Object?>{}));

      await AccountRepository(api.jsonApi).closeAccount('mon-secret');

      final call = api.sent('DELETE', 'api/auth/me/').single;
      expect((call.data as Map)['password'], 'mon-secret');
    },
  );

  test('a session is revoked by its id', () async {
    final api = FakeApi((_) => ok(<String, Object?>{}));

    await AccountRepository(api.jsonApi).revokeSession('abc-123');

    expect(api.sent('DELETE', 'api/auth/sessions/abc-123/'), hasLength(1));
  });

  test('the e-mail is verified with the code, trimmed', () async {
    final api = FakeApi((_) => ok(<String, Object?>{}));
    final repo = AccountRepository(api.jsonApi);

    await repo.sendEmailCode();
    await repo.confirmEmail('  123456 ');

    expect(api.sent('POST', 'api/auth/email/verify/'), hasLength(1));
    expect(
      (api.sent('POST', 'api/auth/email/verify/confirm/').single.data
          as Map)['code'],
      '123456',
    );
  });

  test('notifications are read one by one or all at once', () async {
    final api = FakeApi((_) => ok(<String, Object?>{}));
    final repo = AccountRepository(api.jsonApi);

    await repo.markRead(4);
    await repo.markAllRead();

    expect(api.sent('POST', 'api/notifications/4/read/'), hasLength(1));
    expect(api.sent('POST', 'api/notifications/read_all/'), hasLength(1));
  });

  test('a help request is opened, answered, closed and reopened', () async {
    final api = FakeApi((request) => ok(_ticket()));
    final repo = AccountRepository(api.jsonApi);

    await repo.openTicket(
      subject: 'Paiement absent',
      body: 'Je ne vois pas mon paiement.',
      category: 'payment',
    );
    await repo.replyTicket(8, 'Merci');
    await repo.closeTicket(8, score: 5);
    await repo.reopenTicket(8);

    expect(
      (api.sent('POST', 'api/support/tickets/').single.data as Map)['category'],
      'payment',
    );
    expect(
      (api.sent('POST', 'api/support/tickets/8/reply/').single.data
          as Map)['body'],
      'Merci',
    );
    expect(
      (api.sent('POST', 'api/support/tickets/8/close/').single.data
          as Map)['satisfaction_score'],
      5,
    );
    expect(api.sent('POST', 'api/support/tickets/8/reopen/'), hasLength(1));
  });

  test('a complaint is filed, then withdrawn', () async {
    final api = FakeApi((_) => ok(<String, Object?>{}));
    final repo = AccountRepository(api.jsonApi);

    await repo.fileComplaint(
      type: 'overcharge',
      subject: 'Prix plus haut',
      description: 'Le ticket dit 1 800.',
    );
    await repo.withdrawComplaint(3);

    expect(
      (api.sent('POST', 'api/disputes/').single.data as Map)['complaint_type'],
      'overcharge',
    );
    expect(api.sent('POST', 'api/disputes/3/withdraw/'), hasLength(1));
  });

  test('a refused request surfaces with its error code', () {
    final api = FakeApi(
      (_) => (
        status: 400,
        body: {
          'error': {
            'code': 'invalid',
            'detail': 'Mot de passe actuel incorrect.',
            'fields': {
              'current_password': ['Incorrect.'],
            },
          },
        },
      ),
    );

    expect(
      AccountRepository(api.jsonApi)
          .changePassword(current: 'x', next: 'y', confirm: 'y'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.detail,
          'detail',
          'Mot de passe actuel incorrect.',
        ),
      ),
    );
  });
}
