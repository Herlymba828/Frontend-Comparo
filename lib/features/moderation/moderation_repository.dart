import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/json_api.dart';
import '../account/account_repository.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>(
  (ref) => ModerationRepository(ref.watch(jsonApiProvider)),
);

/// Pending reports the moderator may decide (not their own, not on their
/// own shop), oldest first.
final moderationQueueProvider = FutureProvider.autoDispose<List<Contribution>>(
  (ref) => ref.watch(moderationRepositoryProvider).getQueue(),
);

/// Reports this moderator decided, latest first.
final moderationDecisionsProvider =
    FutureProvider.autoDispose<List<Contribution>>(
      (ref) => ref.watch(moderationRepositoryProvider).getDecisions(),
    );

/// Review decisions, as the API names them.
const reviewDecisionLabels = {
  'accepted': 'Publier le prix',
  'rejected': 'Refuser',
  'duplicate': 'Doublon',
};

class ModerationRepository {
  const ModerationRepository(this._api);

  final JsonApi _api;

  Future<List<Contribution>> getQueue() async => await _api.getAll(
    'api/contributions/',
    Contribution.fromJson,
    query: {'to_review': 1},
  );

  Future<List<Contribution>> getDecisions() async => await _api.getAll(
    'api/contributions/',
    Contribution.fromJson,
    query: {'reviewed_by_me': 1},
  );

  /// Single, final decision; accepting publishes the price.
  Future<void> review(int id, {required String decision, String reason = ''}) =>
      _api.send(
        'api/contributions/$id/review/',
        data: {'decision': decision, 'reason': reason.trim()},
      );
}
