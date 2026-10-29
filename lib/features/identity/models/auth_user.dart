class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    this.roles = const [],
    this.phone = '',
    this.city = '',
  });

  final int id;
  final String email;
  final String displayName;
  final bool emailVerified;

  /// Role slugs granted by the backend (consumer, merchant, courier…).
  final List<String> roles;
  final String phone;
  final String city;

  bool hasRole(String role) => roles.contains(role);

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final displayName = json['display_name'];
    final emailVerified = json['email_verified'];
    if (id is! int ||
        email is! String ||
        displayName is! String ||
        emailVerified is! bool) {
      throw const FormatException('Invalid user profile response.');
    }
    final roles = json['roles'];
    final phone = json['phone'];
    final city = json['city'];
    return AuthUser(
      id: id,
      email: email,
      displayName: displayName,
      emailVerified: emailVerified,
      roles: roles is List ? roles.whereType<String>().toList() : const [],
      phone: phone is String ? phone : '',
      city: city is String ? city : '',
    );
  }
}
