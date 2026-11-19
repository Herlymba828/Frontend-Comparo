import '../../core/json/json_reader.dart';

/// A role held by an account, with its life: active, suspended (with the
/// reason shown to the user) or revoked.
class RoleGrant {
  const RoleGrant({
    required this.id,
    required this.role,
    required this.roleLabel,
    required this.status,
    required this.statusLabel,
    required this.statusReason,
    required this.userId,
    required this.userEmail,
    required this.userName,
  });

  final int id;
  final String role;
  final String roleLabel;
  final String status;
  final String statusLabel;
  final String statusReason;
  final int userId;
  final String userEmail;
  final String userName;

  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';
  bool get isRevoked => status == 'revoked';

  factory RoleGrant.fromJson(Map<String, dynamic> json) {
    final user = json.mapOrNull('user') ?? const <String, dynamic>{};
    return RoleGrant(
      id: json.requireInt('id'),
      role: json.requireString('role'),
      roleLabel: json.string('role_label'),
      status: json.string('status', 'active'),
      statusLabel: json.string('status_label'),
      statusReason: json.string('status_reason'),
      userId: user.intOrNull('id') ?? 0,
      userEmail: user.string('email'),
      userName: user.string('display_name'),
    );
  }
}

/// A document asked for a role (the list is kept by the team, not in the app).
class RoleRequirement {
  const RoleRequirement({
    required this.kind,
    required this.label,
    required this.helpText,
    required this.required,
    required this.expiryRequired,
  });

  final String kind;
  final String label;
  final String helpText;
  final bool required;

  /// Licence, insurance, identity: the role is suspended when it expires.
  final bool expiryRequired;

  factory RoleRequirement.fromJson(Map<String, dynamic> json) =>
      RoleRequirement(
        kind: json.requireString('kind'),
        label: json.string('label'),
        helpText: json.string('help_text'),
        required: json.flag('required', true),
        expiryRequired: json.flag('expiry_required'),
      );
}

/// A document sent with an application, and what the reviewer decided.
class ApplicationDocument {
  const ApplicationDocument({
    required this.id,
    required this.kind,
    required this.kindLabel,
    required this.status,
    required this.rejectionReason,
    required this.downloadUrl,
    this.expiresOn,
    this.createdAt,
  });

  final int id;
  final String kind;
  final String kindLabel;

  /// `pending`, `accepted` or `rejected`.
  final String status;
  final String rejectionReason;
  final String downloadUrl;
  final DateTime? expiresOn;
  final DateTime? createdAt;

  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  factory ApplicationDocument.fromJson(Map<String, dynamic> json) =>
      ApplicationDocument(
        id: json.requireInt('id'),
        kind: json.string('kind', 'other'),
        kindLabel: json.string('kind_label', 'Autre justificatif'),
        status: json.string('status', 'pending'),
        rejectionReason: json.string('rejection_reason'),
        downloadUrl: json.string('download_url'),
        expiresOn: json.dateOrNull('expires_on'),
        createdAt: json.dateOrNull('created_at'),
      );
}

/// One request for one role, from its draft to the decision.
class RoleApplication {
  const RoleApplication({
    required this.id,
    required this.role,
    required this.roleLabel,
    required this.status,
    required this.statusLabel,
    required this.details,
    required this.invited,
    required this.applicantId,
    required this.applicantName,
    required this.applicantEmail,
    required this.applicantPhone,
    required this.reviewerMessage,
    required this.rejectionLabel,
    required this.requirements,
    required this.missing,
    required this.documents,
    this.shopName,
    this.submittedAt,
  });

  final int id;
  final String role;
  final String roleLabel;
  final String status;
  final String statusLabel;

  /// The answers specific to the role (a courier's vehicle, phone, zones).
  final Map<String, dynamic> details;
  final bool invited;
  final int applicantId;
  final String applicantName;
  final String applicantEmail;
  final String applicantPhone;

  /// What the reviewer asks to complete, or why the request was refused.
  final String reviewerMessage;
  final String rejectionLabel;
  final List<RoleRequirement> requirements;

  /// Kinds of required documents not sent (or refused).
  final List<String> missing;
  final List<ApplicationDocument> documents;
  final String? shopName;
  final DateTime? submittedAt;

  /// The applicant can still change it (draft, or a complement was asked).
  bool get isEditable => status == 'draft' || status == 'info_requested';
  bool get isUnderReview => status == 'submitted' || status == 'in_review';
  bool get isOpen => isEditable || isUnderReview;
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get vehicle => (details['vehicle'] as String?) ?? '';
  String get phone => (details['phone'] as String?) ?? '';

  /// The document sent for [kind] that counts (a refused one does not).
  ApplicationDocument? documentFor(String kind) {
    ApplicationDocument? found;
    for (final document in documents) {
      if (document.kind != kind) {
        continue;
      }
      if (!document.isRejected) {
        return document;
      }
      found ??= document;
    }
    return found;
  }

  factory RoleApplication.fromJson(Map<String, dynamic> json) {
    final applicant = json.mapOrNull('applicant') ?? const <String, dynamic>{};
    final details = json.mapOrNull('details') ?? const <String, dynamic>{};
    return RoleApplication(
      id: json.requireInt('id'),
      role: json.requireString('role'),
      roleLabel: json.string('role_label'),
      status: json.string('status', 'draft'),
      statusLabel: json.string('status_label'),
      details: details,
      invited: json.flag('invited'),
      applicantId: applicant.intOrNull('id') ?? 0,
      applicantName: applicant.string('display_name'),
      applicantEmail: applicant.string('email'),
      applicantPhone: applicant.string('phone'),
      reviewerMessage: json.string('reviewer_message'),
      rejectionLabel: json.string('rejection_label'),
      requirements: json
          .maps('requirements')
          .map(RoleRequirement.fromJson)
          .toList(),
      missing: [
        for (final kind in (json['missing'] as List? ?? const []))
          if (kind is String) kind,
      ],
      documents: json
          .maps('documents')
          .map(ApplicationDocument.fromJson)
          .toList(),
      shopName: json.mapOrNull('shop')?.stringOrNull('name'),
      submittedAt: json.dateOrNull('submitted_at'),
    );
  }
}

/// `GET /api/roles/mine/`: my roles and my applications.
class MyRoles {
  const MyRoles({required this.grants, required this.applications});

  final List<RoleGrant> grants;
  final List<RoleApplication> applications;

  RoleGrant? grantFor(String role) {
    for (final grant in grants) {
      if (grant.role == role) {
        return grant;
      }
    }
    return null;
  }

  /// The application in progress for [role], if any.
  RoleApplication? openApplicationFor(String role) {
    for (final application in applications) {
      if (application.role == role && application.isOpen) {
        return application;
      }
    }
    return null;
  }

  /// The latest application for [role], open or not.
  RoleApplication? latestApplicationFor(String role) {
    for (final application in applications) {
      if (application.role == role) {
        return application;
      }
    }
    return null;
  }

  factory MyRoles.fromJson(Map<String, dynamic> json) => MyRoles(
    grants: json.maps('grants').map(RoleGrant.fromJson).toList(),
    applications: json
        .maps('applications')
        .map(RoleApplication.fromJson)
        .toList(),
  );
}

/// French labels of the vehicles a courier can declare.
const courierVehicles = {
  'foot': 'À pied',
  'bicycle': 'Vélo',
  'motorbike': 'Moto',
  'car': 'Voiture',
  'van': 'Utilitaire',
};

/// Why an application is refused (the server's codes).
const rejectionReasons = {
  'documents_invalid': 'Justificatifs non conformes',
  'documents_missing': 'Justificatifs manquants',
  'identity_mismatch': 'Identité non concordante',
  'record': 'Antécédents incompatibles avec le rôle',
  'fraud': 'Suspicion de fraude',
  'other': 'Autre motif',
};

/// French labels for statuses (applications, documents and roles).
const roleStatusLabels = {
  'draft': 'Brouillon',
  'submitted': 'Soumise',
  'in_review': 'En examen',
  'info_requested': 'Complément demandé',
  'approved': 'Acceptée',
  'rejected': 'Refusée',
  'withdrawn': 'Retirée',
  'pending': 'À examiner',
  'accepted': 'Accepté',
  'active': 'Actif',
  'suspended': 'Suspendu',
  'revoked': 'Révoqué',
};
