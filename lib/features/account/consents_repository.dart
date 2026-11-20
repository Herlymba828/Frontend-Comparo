import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json/json_reader.dart';
import '../../core/network/json_api.dart';

/// The person's answer for one purpose (BR-102): refused until they say yes.
class Consent {
  const Consent({
    required this.purpose,
    required this.label,
    required this.granted,
  });

  final String purpose;
  final String label;
  final bool granted;

  factory Consent.fromJson(Map<String, dynamic> json) => Consent(
    purpose: json.requireString('purpose'),
    label: json.string('label'),
    granted: json.flag('granted'),
  );
}

/// What each purpose is used for, in words a person can weigh.
const consentExplanations = {
  'location':
      'Partager votre position, par exemple pour être suivi pendant une '
      'livraison. Effacée 30 jours après la fin de la livraison.',
  'analytics': 'Mesurer l’usage de l’application pour l’améliorer.',
  'marketing': 'Recevoir des offres et des nouveautés.',
  'personalization': 'Adapter les suggestions à vos habitudes.',
};

/// The API's code when an action needs a consent the person has not given.
const consentRequiredCode = 'consent_required';

final consentsRepositoryProvider = Provider<ConsentsRepository>(
  (ref) => ConsentsRepository(ref.watch(jsonApiProvider)),
);

final consentsProvider = FutureProvider.autoDispose<List<Consent>>(
  (ref) => ref.watch(consentsRepositoryProvider).getAll(),
);

class ConsentsRepository {
  const ConsentsRepository(this._api);

  final JsonApi _api;

  Future<List<Consent>> getAll() =>
      _api.getAll('api/auth/consents/', Consent.fromJson);

  Future<Consent> set(String purpose, {required bool granted}) => _api.patch(
    'api/auth/consents/$purpose/',
    Consent.fromJson,
    data: {'granted': granted},
  );
}
