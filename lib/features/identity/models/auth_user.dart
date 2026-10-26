class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
  });

  final int id;
  final String email;
  final String displayName;
  final bool emailVerified;

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
    return AuthUser(
      id: id,
      email: email,
      displayName: displayName,
      emailVerified: emailVerified,
    );
  }
}
