import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/files/upload_file.dart';
import '../../core/network/json_api.dart';
import 'roles_models.dart';

final rolesRepositoryProvider = Provider<RolesRepository>(
  (ref) => RolesRepository(ref.watch(jsonApiProvider)),
);

/// My roles (with their status) and my applications.
final myRolesProvider = FutureProvider.autoDispose<MyRoles>(
  (ref) => ref.watch(rolesRepositoryProvider).mine(),
);

final roleApplicationProvider = FutureProvider.autoDispose
    .family<RoleApplication, int>(
      (ref, id) => ref.watch(rolesRepositoryProvider).application(id),
    );

/// Applications waiting for a decision (reviewers).
final applicationsToReviewProvider = FutureProvider.autoDispose
    .family<List<RoleApplication>, String?>(
      (ref, role) => ref.watch(rolesRepositoryProvider).reviewQueue(role: role),
    );

/// Roles held by other accounts, for the team that manages them.
final managedGrantsProvider = FutureProvider.autoDispose
    .family<List<RoleGrant>, String?>(
      (ref, role) => ref.watch(rolesRepositoryProvider).grants(role: role),
    );

class RolesRepository {
  const RolesRepository(this._api);

  final JsonApi _api;

  // ── Applicant ─────────────────────────────────────────────────────────
  Future<MyRoles> mine() => _api.getOne('api/roles/mine/', MyRoles.fromJson);

  Future<RoleApplication> application(int id) =>
      _api.getOne('api/roles/applications/$id/', RoleApplication.fromJson);

  Future<RoleApplication> start(
    String role, {
    Map<String, Object?> details = const {},
  }) => _api.post(
    'api/roles/applications/',
    RoleApplication.fromJson,
    data: {'role': role, 'details': details},
  );

  Future<RoleApplication> updateDetails(int id, Map<String, Object?> details) =>
      _api.patch(
        'api/roles/applications/$id/',
        RoleApplication.fromJson,
        data: {'details': details},
      );

  Future<void> addDocument(
    int id, {
    required String kind,
    required UploadFile file,
    DateTime? expiresOn,
  }) => _api.postForm(
    'api/roles/applications/$id/documents/',
    (json) => json,
    fields: {
      'kind': kind,
      'expires_on': expiresOn == null ? null : _date(expiresOn),
    },
    files: {'file': file.toMultipart()},
  );

  Future<void> deleteDocument(int id, int documentId) =>
      _api.delete('api/roles/applications/$id/documents/$documentId/');

  Future<RoleApplication> submit(int id) =>
      _api.post('api/roles/applications/$id/submit/', RoleApplication.fromJson);

  Future<RoleApplication> withdraw(int id) => _api.post(
    'api/roles/applications/$id/withdraw/',
    RoleApplication.fromJson,
  );

  // ── Reviewer ──────────────────────────────────────────────────────────
  Future<List<RoleApplication>> reviewQueue({String? role}) => _api.getAll(
    'api/roles/applications/review/',
    RoleApplication.fromJson,
    query: {'role': role},
  );

  Future<RoleApplication> startReview(int id) => _api.post(
    'api/roles/applications/$id/start_review/',
    RoleApplication.fromJson,
  );

  Future<RoleApplication> requestInfo(int id, String message) => _api.post(
    'api/roles/applications/$id/request_info/',
    RoleApplication.fromJson,
    data: {'message': message},
  );

  Future<RoleApplication> approve(int id, {String message = ''}) => _api.post(
    'api/roles/applications/$id/approve/',
    RoleApplication.fromJson,
    data: {'message': message},
  );

  Future<RoleApplication> reject(
    int id, {
    required String reason,
    required String message,
  }) => _api.post(
    'api/roles/applications/$id/reject/',
    RoleApplication.fromJson,
    data: {'reason': reason, 'message': message},
  );

  Future<void> decideDocument(
    int id,
    int documentId, {
    required bool accepted,
    String reason = '',
  }) => _api.send(
    'api/roles/applications/$id/documents/$documentId/decide/',
    data: {'accepted': accepted, 'reason': reason},
  );

  // ── Roles held by others ──────────────────────────────────────────────
  Future<List<RoleGrant>> grants({String? role, String? status}) => _api.getAll(
    'api/roles/grants/',
    RoleGrant.fromJson,
    query: {'role': role, 'status': status},
  );

  Future<void> suspend(int grantId, String reason) =>
      _api.send('api/roles/grants/$grantId/suspend/', data: {'reason': reason});

  Future<void> reactivate(int grantId, [String reason = '']) => _api.send(
    'api/roles/grants/$grantId/reactivate/',
    data: {'reason': reason},
  );

  Future<void> revoke(int grantId, String reason) =>
      _api.send('api/roles/grants/$grantId/revoke/', data: {'reason': reason});

  /// An admin invites an existing account to a staff role.
  Future<RoleApplication> invite({
    required String email,
    required String role,
  }) => _api.post(
    'api/roles/invitations/',
    RoleApplication.fromJson,
    data: {'email': email, 'role': role},
  );

  static String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
